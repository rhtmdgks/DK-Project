package com.wearegoodwill.laon.glance

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class MealDepartureWidgetReceiver : HomeWidgetGlanceWidgetReceiver<MealDepartureGlanceWidget>() {
    override val glanceAppWidget = MealDepartureGlanceWidget()
}
