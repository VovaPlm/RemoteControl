package com.remotecontrol

import android.content.pm.ActivityInfo
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import com.remotecontrol.ui.screens.ConnectScreen
import com.remotecontrol.ui.screens.RemoteScreen
import com.remotecontrol.ui.theme.BinanceBackground
import com.remotecontrol.ui.theme.RemoteControlTheme
import com.remotecontrol.viewmodel.ConnectionState
import com.remotecontrol.viewmodel.MainViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            RemoteControlTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = BinanceBackground
                ) {
                    App()
                }
            }
        }
    }
}

@Composable
fun App(viewModel: MainViewModel = viewModel()) {
    val activity = LocalContext.current as? MainActivity
    LaunchedEffect(viewModel.connectionState) {
        when (viewModel.connectionState) {
            ConnectionState.CONNECTED -> activity?.requestedOrientation =
                ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
            else -> activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
    }

    if (viewModel.connectionState == ConnectionState.CONNECTED) {
        RemoteScreen(viewModel = viewModel)
    } else {
        ConnectScreen(
            host = viewModel.serverHost,
            port = viewModel.serverPort,
            connectionState = viewModel.connectionState,
            errorMessage = viewModel.errorMessage,
            onHostChange = { viewModel.serverHost = it },
            onPortChange = { viewModel.serverPort = it },
            onConnect = { viewModel.connect() }
        )
    }
}
