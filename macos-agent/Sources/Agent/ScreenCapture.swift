import Foundation
import CoreGraphics
import CoreVideo
import VideoToolbox
import IOSurface
import CoreMedia

final class ScreenCapture {
    static func videoSize() -> CGSize {
        let bounds = CGDisplayBounds(CGMainDisplayID())
        let w = bounds.size.width
        let h = bounds.size.height
        let scale = min(1920 / w, 1080 / h)
        return CGSize(width: w * scale, height: h * scale)
    }
    var onEncodedFrame: ((Data) -> Void)?
    var fps: Double = 15

    private var compressionSession: VTCompressionSession?
    private var displayStream: CGDisplayStream?
    private let encodeQueue = DispatchQueue(
        label: "encode.queue",
        qos: .userInteractive
    )
    private var previousSPSPPS: Data?

    let videoWidth: Int
    let videoHeight: Int

    init() {
        let bounds = CGDisplayBounds(CGMainDisplayID())
        let w = bounds.size.width
        let h = bounds.size.height
        let scale = min(1920 / w, 1080 / h)
        videoWidth = Int(w * scale)
        videoHeight = Int(h * scale)
    }

    func start() {
        setupCompression()
        setupDisplayStream()
    }

    func stop() {
        displayStream?.stop()
        displayStream = nil
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
    }

    // MARK: - Compression Session

    private func setupCompression() {
        let sourceAttrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferWidthKey: videoWidth,
            kCVPixelBufferHeightKey: videoHeight,
        ]

        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(videoWidth),
            height: Int32(videoHeight),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: sourceAttrs as CFDictionary,
            compressedDataAllocator: kCFAllocatorDefault,
            outputCallback: Self.compressionCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            print("Failed to create compression session: \(status)")
            return
        }

        self.compressionSession = session

        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime,
                             value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel,
                             value: kVTProfileLevel_H264_Main_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate,
                             value: NSNumber(value: fps))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval,
                             value: NSNumber(value: Int32(fps * 2)))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate,
                             value: NSNumber(value: 2_000_000))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_DataRateLimits,
                             value: [3_000_000, 1] as CFArray)

        VTCompressionSessionPrepareToEncodeFrames(session)
    }

    // MARK: - Display Stream

    private func setupDisplayStream() {
        let displayID = CGMainDisplayID()
        let stream = CGDisplayStream(
            dispatchQueueDisplay: displayID,
            outputWidth: videoWidth,
            outputHeight: videoHeight,
            pixelFormat: Int32(kCVPixelFormatType_32BGRA),
            properties: [
                CGDisplayStream.queueDepth: 3,
                CGDisplayStream.minimumFrameTime: NSNumber(value: 1.0 / fps),
            ] as CFDictionary,
            queue: encodeQueue
        ) { [weak self] status, _, frameSurface, _ in
            guard status == .frameComplete, let surface = frameSurface else { return }
            self?.encodeSurface(surface)
        }

        displayStream = stream
        stream?.start()
    }

    // MARK: - Encode

    private func encodeSurface(_ surface: IOSurface) {
        guard let session = compressionSession else { return }

        var unmanagedPb: Unmanaged<CVPixelBuffer>?
        let status = CVPixelBufferCreateWithIOSurface(
            kCFAllocatorDefault,
            surface,
            nil,
            &unmanagedPb
        )

        guard status == kCVReturnSuccess, let unmanaged = unmanagedPb else { return }
        let buffer = unmanaged.takeRetainedValue()

        let elapsed = CMClockGetTime(CMClockGetHostTimeClock())
        let pts = CMTime(value: elapsed.value, timescale: elapsed.timescale)

        VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: buffer,
            presentationTimeStamp: pts,
            duration: .invalid,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )
    }

    // MARK: - Compression Output

    static let compressionCallback: VTCompressionOutputCallback = {
        refcon, _, status, _, sampleBuffer in
        guard status == noErr, let sampleBuffer = sampleBuffer else { return }
        let capture = Unmanaged<ScreenCapture>.fromOpaque(refcon!).takeUnretainedValue()
        capture.outputEncodedFrame(sampleBuffer)
    }

    private func outputEncodedFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer)
        else { return }

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)
        else { return }

        var ptr: UnsafeMutablePointer<Int8>?
        var length: Int = 0
        let bufStatus = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &ptr
        )
        guard bufStatus == kCMBlockBufferNoErr, let rawPtr = ptr else { return }

        let dataPtr = UnsafeRawPointer(rawPtr)

        var output = Data()
        output.reserveCapacity(length + 64)

        let isKeyframe = isKeyframeSample(sampleBuffer)

        if isKeyframe {
            let sps = getParameterSet(formatDesc, index: 0)
            let pps = getParameterSet(formatDesc, index: 1)

            if let sps = sps, let pps = pps {
                let spspps = Data(sps) + Data(pps)
                if spspps != previousSPSPPS {
                    previousSPSPPS = spspps
                    output.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
                    output.append(contentsOf: sps)
                    output.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
                    output.append(contentsOf: pps)
                }
            }
        }

        var offset = 0
        while offset + 4 <= length {
            let nalLen = Int(
                dataPtr.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian
            )
            offset += 4
            if offset + nalLen <= length {
                output.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
                let slice = Data(bytes: dataPtr.advanced(by: offset), count: nalLen)
                output.append(slice)
                offset += nalLen
            } else {
                break
            }
        }

        if !output.isEmpty {
            onEncodedFrame?(output)
        }
    }

    private func isKeyframeSample(_ sb: CMSampleBuffer) -> Bool {
        guard let arr = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false)
        else { return false }
        let count = CFArrayGetCount(arr)
        guard count > 0 else { return false }
        let dict = unsafeBitCast(CFArrayGetValueAtIndex(arr, 0), to: CFDictionary.self)
        let notSync = CFDictionaryGetValue(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque())
        return notSync == nil
    }

    private func getParameterSet(_ desc: CMFormatDescription, index: Int) -> Data? {
        var ptr: UnsafePointer<UInt8>?
        var size: Int = 0
        var count: Int = 0
        var nalLen: Int32 = 0

        let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            desc,
            parameterSetIndex: index,
            parameterSetPointerOut: &ptr,
            parameterSetSizeOut: &size,
            parameterSetCountOut: &count,
            nalUnitHeaderLengthOut: &nalLen
        )

        guard status == noErr, let buf = ptr, size > 0 else { return nil }
        return Data(bytes: buf, count: size)
    }
}
