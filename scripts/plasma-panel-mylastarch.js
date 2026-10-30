// Curated Pi-safe version of the original MyLastArch Plasma panel.
var oldPanels = panels();
for (var i = 0; i < oldPanels.length; ++i) {
    oldPanels[i].remove();
}

var panel = new Panel();
panel.location = "top";
panel.height = 36;
panel.floating = false;
panel.alignment = "center";
panel.lengthMode = "fill";
panel.addWidget("org.kde.plasma.kicker");
panel.addWidget("org.kde.plasma.appmenu");
panel.addWidget("org.kde.plasma.panelspacer");
panel.addWidget("org.kde.plasma.windowlist");
panel.addWidget("org.kde.plasma.systemtray");
panel.addWidget("org.kde.plasma.digitalclock");
