package com.remotecontrol.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.remotecontrol.ui.theme.BinancePrimary
import com.remotecontrol.ui.theme.BinanceSurface
import com.remotecontrol.ui.theme.BinanceSurfaceVariant
import com.remotecontrol.ui.theme.BinanceTextPrimary
import com.remotecontrol.ui.theme.BinanceTextSecondary
import com.remotecontrol.ui.theme.BinanceYellow10
import com.remotecontrol.viewmodel.ConnectionState

@Composable
fun ConnectScreen(
    host: String,
    port: String,
    connectionState: ConnectionState,
    errorMessage: String,
    onHostChange: (String) -> Unit,
    onPortChange: (String) -> Unit,
    onConnect: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.fillMaxWidth()
        ) {
            // Logo / Title
            Text(
                text = "Remote",
                fontSize = 36.sp,
                fontWeight = FontWeight.Bold,
                color = BinanceTextPrimary
            )
            Text(
                text = "Control",
                fontSize = 36.sp,
                fontWeight = FontWeight.Bold,
                color = BinancePrimary
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "Connect to your macOS agent",
                fontSize = 14.sp,
                color = BinanceTextSecondary
            )

            Spacer(modifier = Modifier.height(32.dp))

            // Connection Card
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = BinanceSurface)
            ) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text(
                        text = "Server",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = BinanceTextSecondary,
                        modifier = Modifier.padding(bottom = 12.dp)
                    )

                    OutlinedTextField(
                        value = host,
                        onValueChange = onHostChange,
                        label = { Text("Tailscale IP or hostname") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(8.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = BinancePrimary,
                            unfocusedBorderColor = BinanceSurfaceVariant,
                            focusedLabelColor = BinancePrimary,
                            unfocusedLabelColor = BinanceTextSecondary,
                            cursorColor = BinancePrimary,
                            focusedTextColor = BinanceTextPrimary,
                            unfocusedTextColor = BinanceTextPrimary,
                        ),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri)
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    OutlinedTextField(
                        value = port,
                        onValueChange = onPortChange,
                        label = { Text("Port") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(8.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = BinancePrimary,
                            unfocusedBorderColor = BinanceSurfaceVariant,
                            focusedLabelColor = BinancePrimary,
                            unfocusedLabelColor = BinanceTextSecondary,
                            cursorColor = BinancePrimary,
                            focusedTextColor = BinanceTextPrimary,
                            unfocusedTextColor = BinanceTextPrimary,
                        ),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                    )
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Connect Button
            Button(
                onClick = onConnect,
                enabled = connectionState != ConnectionState.CONNECTING,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(8.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = BinancePrimary,
                    contentColor = BinanceSurface,
                    disabledContainerColor = BinanceSurfaceVariant
                )
            ) {
                if (connectionState == ConnectionState.CONNECTING) {
                    CircularProgressIndicator(
                        color = BinanceSurface,
                        modifier = Modifier.height(20.dp),
                        strokeWidth = 2.dp
                    )
                } else {
                    Text(
                        text = "Connect",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            // Error
            if (errorMessage.isNotEmpty()) {
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = errorMessage,
                    color = MaterialTheme.colorScheme.error,
                    fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Info hint
            Text(
                text = "Make sure the macOS agent is running\nand accessible via Tailscale",
                fontSize = 12.sp,
                color = BinanceTextSecondary,
                textAlign = TextAlign.Center,
                lineHeight = 18.sp
            )
        }
    }
}
