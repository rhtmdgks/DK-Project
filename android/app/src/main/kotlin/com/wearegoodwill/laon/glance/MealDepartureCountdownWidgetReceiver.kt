package com.wearegoodwill.laon.glance

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class MealDepartureCountdownWidgetReceiver : HomeWidgetGlanceWidgetReceiver<MealDepartureCountdownGlanceWidget>() {
    override val glanceAppWidget = MealDepartureCountdownGlanceWidget()
}
