package com.wearegoodwill.laon.glance

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color as ComposeColor
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.wearegoodwill.laon.MainActivity
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity

/**
 * 급식 출발 카운트다운 홈 위젯. 탭 시 앱을 연다.
 */
class MealDepartureCountdownGlanceWidget : GlanceAppWidget() {

    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent { GlanceContent(context, currentState()) }
    }

    @Composable
    private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {
        val openAppUri = Uri.parse("laon://")
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(ColorProvider(ComposeColor(0xFF00B894)))
                .padding(16.dp)
                .clickable(onClick = actionStartActivity<MainActivity>(context, openAppUri)),
            verticalAlignment = Alignment.Vertical.CenterVertically,
            horizontalAlignment = Alignment.Horizontal.CenterHorizontally,
        ) {
            Text(
                text = "급식 출발",
                style = TextStyle(
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = ColorProvider(ComposeColor.White),
                ),
            )
            Text(
                text = "탭하여 열기",
                style = TextStyle(
                    fontSize = 12.sp,
                    color = ColorProvider(ComposeColor.White.copy(alpha = 0.9f)),
                ),
            )
        }
    }
}
