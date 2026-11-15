// Selene Night — disposition du bureau
//  • barre supérieure fine : lanceur (logo) · horloge centrée · zone de notification
//  • dock flottant en bas : applications épinglées et fenêtres ouvertes

// --- Fond d'écran ----------------------------------------------------------
var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    var desk = desktopsArray[j];
    desk.wallpaperPlugin = 'org.kde.image';
    desk.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
    desk.writeConfig('Image', 'file:///usr/share/wallpapers/SeleneNight/contents/images/2880x1800.jpg');
}

// --- Barre supérieure ------------------------------------------------------
var topBar = new Panel;
topBar.location = 'top';
topBar.height = 2 * Math.ceil(gridUnit * 1.7 / 2);
topBar.floating = false;
topBar.hiding = 'none';

var launcher = topBar.addWidget('org.kde.plasma.kickoff');
launcher.currentConfigGroup = ['General'];
launcher.writeConfig('icon', 'selene');
topBar.addWidget('org.kde.plasma.panelspacer');
topBar.addWidget('org.kde.plasma.digitalclock');
topBar.addWidget('org.kde.plasma.panelspacer');
topBar.addWidget('org.kde.plasma.systemtray');

// --- Dock flottant (applications épinglées si elles sont installées) -------
var candidates = [
    ['dolphin', 'org.kde.dolphin.desktop'],
    ['firefox', 'firefox.desktop'],
    ['konsole', 'org.kde.konsole.desktop'],
    ['steam', 'steam.desktop'],
    ['kate', 'org.kde.kate.desktop'],
    ['systemsettings', 'systemsettings.desktop']
];
var pinned = [];
for (var i = 0; i < candidates.length; i++) {
    if (applicationPath(candidates[i][0])) {
        pinned.push('applications:' + candidates[i][1]);
    }
}

var dock = new Panel;
dock.location = 'bottom';
dock.height = 2 * Math.ceil(gridUnit * 3 / 2);
dock.alignment = 'center';
dock.lengthMode = 'fit';
dock.floating = true;
dock.hiding = 'none';

var tasks = dock.addWidget('org.kde.plasma.icontasks');
tasks.currentConfigGroup = ['General'];
tasks.writeConfig('launchers', pinned.join(','));
