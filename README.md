Overview
========

Populates a ComboBox in BEML named "renditionCombo", displaying various
choices for rendition quality selection.

This plugin works with progressive or streaming video. In the case of
progressive download the video is loaded again and has to start
from the beginning.

Downloading the Plugin
======================

Versioned downloads of the SWF are available by clicking the Downloads button
on Github and then selecting one of the download packages available.

Compiling the plugin
====================

Download free Adobe Flex SDK from Adobe website: http://www.adobe.com/go/flex_sdk

    cd /path/to/Rendition-Selector-Plugin/RenditionSelector/
    /path/to/flex_sdk/bin/mxmlc -library-path+=libs -static-link-runtime-shared-libraries=true -o RenditionSelector.swf src/RenditionSelector.as 

Configuring the Plugin
======================

The format for specifying choices is as follows:

    RenditionSelector.swf?choices=LOW,200-400|MED,700-900|HIGH,1000-1300|HD,1600-2000&default=MED&spinner=true&spinnerbg=false

In this example, 4 choices will be added to the ComboBox
and they will be matched up to renditions which fall within
the range of bitrates specified. For HD, a rendition
that has an encoding rate between 1600 and 2000 kbps
will be used. If one can't be found, then the HD choice would
be left out. If more than one rendition exists within that
range then the user's bandwidth is taken into account and
the best rendition is selected.

- Choices are separated by a | (pipe)
- The label that is displayed is separated from the encoding rage by a , (comma)
- The encoding range is separated by a - (dash)

The order can be changed and will then be reflected in the ComboBox.

A negative one value (-1) is a special value that designates auto rendition
selection. An example for how that might look is below.

    RenditionSelector.swf?choices=LOW,200-400|MED,700-900|HIGH,1000-1300|HD,1600-2000|AUTO,-1&default=MED

All of the labels can be changed, HD, HIGH, MED, LOW and AUTO have no special meaning.

The param "default" informs the selector which choice to default the ComboBox to.

The param "spinner" toggles the visibility of a loading spinner which appears during rendition changes.

The param "spinnerbg" toggles the background that appears along with the spinner icon.

Configuring the BEML
====================

A ComboBox component with the id "renditionCombo" needs to be added to 
the BEML for the player and two sample BEML templates have been included.