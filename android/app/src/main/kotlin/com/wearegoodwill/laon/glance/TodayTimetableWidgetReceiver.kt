package com.wearegoodwill.laon.glance

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class TodayTimetableWidgetReceiver : HomeWidgetGlanceWidgetReceiver<TodayTimetableGlanceWidget>() {
    override val glanceAppWidget = TodayTimetableGlanceWidget()
}
