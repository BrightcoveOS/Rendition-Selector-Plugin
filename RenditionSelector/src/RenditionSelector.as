package 
{
    import com.brightcove.api.APIModules;
    import com.brightcove.api.CustomModule;
    import com.brightcove.api.components.ComboBox;
    import com.brightcove.api.dtos.RenditionAssetDTO;
    import com.brightcove.api.dtos.RenditionSelectionContext;
    import com.brightcove.api.dtos.VideoDTO;
    import com.brightcove.api.events.MediaEvent;
    import com.brightcove.api.events.PropertyChangeEvent;
    import com.brightcove.api.modules.ExperienceModule;
    import com.brightcove.api.modules.VideoPlayerModule;
    
    import flash.display.Stage;
    import flash.events.FullScreenEvent;
    import flash.events.TimerEvent;
    import flash.utils.Timer;
    
    /**
     * Rendition selector.
     * 
     * Populates a ComboBox in BEML named "renditionCombo", displaying various
     * choices for rendition quality selection. The format for specifying 
     * choices is as follows:
     * 
     * RenditionSelector.swf?choices=AUTO,-1|HD,2200-3000|HIGH,1500-1800|MED,700-1000|LOW,300-400&default=MED
     * 
     * In this example, 4 choices will be added to the ComboBox
     * and they will be matched up to renditions which fall within
     * the range of bitrates specified. For HD, a rendition
     * that has an encoding rate between 2200 and 3000 kbps
     * will be used. If one can't be found, then the HD choice would
     * be left out.
     * 
     * Choices are seperated by a | (pipe)
     * Encoding ranges are separated by a - (dash)
     * Labels and ranges are separated by a , (comma)
     * 
     * Specifing -1 as the range will result in an option which
     * defaults to the normal player logic for choosing 
     * a rendition.
     *
     * The param "default" informs the selector which choice
     * to default the ComboBox to.
     */
    public class RenditionSelector 
        extends CustomModule
    {
        private static const COMBOBOX_ID:String = "renditionCombo";
        
        private var _experienceModule:ExperienceModule;
        private var _videoPlayerModule:VideoPlayerModule;
        private var _renditionCombo:ComboBox;
        private var _choices:Array;
        private var _defaultChoice:String;
        private var _currentVideo:VideoDTO;
        private var _tim:Timer;
        private var _stage:Stage;
        
        /**
         * @inheritDoc
         */
        override protected function initialize():void
        {
            _experienceModule = player.getModule(APIModules.EXPERIENCE) as ExperienceModule;
            _videoPlayerModule = player.getModule(APIModules.VIDEO_PLAYER) as VideoPlayerModule;
            
            debug("initializing rendition selector plugin");
            
            _renditionCombo = _experienceModule.getElementByID(COMBOBOX_ID) as ComboBox;
            
            // check to make sure the ComboBox is ready, there is a bug which came up
            // while rendering the component in a chromeless player which causes
            // the templateLoaded event to fire before the ComboBox component is ready
            if (comboBoxReady())
            {
                start();
            }
            else
            {
                _tim = new Timer(50, 100);
                _tim.addEventListener(TimerEvent.TIMER, handleTimer, false, 0, true);
                _tim.start();
            }
        }
        
        /**
         * Checks for any choices that were specified and populates
         * the rendition selection ComboBox.
         */
        private function start():void
        {
            _stage = _experienceModule.getStage();
            
            _currentVideo = _videoPlayerModule.getCurrentVideo();
            
            _videoPlayerModule.setRenditionSelectionCallback(handleRenditionSelection);
            _videoPlayerModule.addEventListener(MediaEvent.CHANGE, handleMediaChange);
            
            parseChoices();
            populateRenditionCombo();
        }
        
        /**
         * Timer handler which checks to see if the ComboBox is ready.
         */
        private function handleTimer(event:TimerEvent):void
        {
            if (comboBoxReady())
            {
                start();
                _tim.stop();
                _tim = null;
            }
        }
        
        /**
         * Checks to see if the ComboBox is ready by attempting to
         * set the label field. If it's not ready a NPE is thrown
         * which is caught here.
         */
        private function comboBoxReady():Boolean
        {        
            try 
            {
                _renditionCombo.setLabelField("label");
            }
            catch (e:Error) 
            {
                return false;
            }
            return true;
        }
        
        /**
         * Handles any changes when a new video is loaded. Since this
         * rendition selection module is made for a PD video, loadVideo
         * is called each time a rendition selection is made. That means
         * that we need to compare the new video ID to make sure a 
         * different video was actually loaded.
         */
        private function handleMediaChange(event:MediaEvent):void
        {
            debug("handleMediaChange");
            if (_currentVideo && _currentVideo.id != _videoPlayerModule.getCurrentVideo().id)
            {
                debug("new video was loaded");
                _currentVideo = _videoPlayerModule.getCurrentVideo();
                populateRenditionCombo();
                reloadVideo();
            }
        }
        
        /**
         * Handles the rendition selection logic. If there are no choices then just
         * default to what the player wants to do by returning a -1.
         */
        private function handleRenditionSelection(context:RenditionSelectionContext):Number
        {
            debug("handleRenditionSelection");
            if (_choices)
            {
                var index:Number = -1;
                var renditions:Array = _renditionCombo.getSelectedData().value;
                for (var i:int = 0; i < renditions.length; i++)
                {
                    var rendition:Object = renditions[i];
                    
                    // if this is the last rendition for the choice or if the detected
                    // bandwidth is higher than the rendition's encoding rate
                    // then return that rendition's index
                    // this works because the renditions for a particular choice 
                    // are ordered by highest to lowest bit rate
                    if (context.detectedBandwidth >= rendition.encodingRate ||
                        i == renditions.length-1)
                    {
                        debug("detected bandwidth: " + context.detectedBandwidth);
                        debug("renditions length: " + renditions.length);
                        debug("rendition encoding rate: " + rendition.encodingRate);
                        debug("rendition index: " + rendition.index);
                        index = rendition.index;
                        break;
                    }
                }
                return index;
            }
            return -1;
        }
        
        /**
         * Handles any selections made on the ComboBox.
         */
        private function handleRenditionComboChange(event:PropertyChangeEvent):void
        {
            debug("handleRenditionComboChange");
            if (event.property == "selectedItem") 
            {
                if (_videoPlayerModule.getCurrentVideo().FLVFullLengthStreamed)
                {
                    resizeVideo();
                }
                else
                {
                    reloadVideo();
                }
            }
        }
        
        /**
         * Resizes the video player which then causes the rendition logic
         * to kick in.
         */
        private function resizeVideo():void
        {
            debug("toggling video size");
            var oldWidth:Number = _videoPlayerModule.getWidth();
            var oldHeight:Number = _videoPlayerModule.getHeight();
            
            _videoPlayerModule.setSize(oldWidth, oldHeight-1);
            _videoPlayerModule.setSize(oldWidth, oldHeight);
        }
        
        /**
         * Reloads the current video which needs to happen when a rendition
         * selection has been made. When the video starts over, the rendition
         * selection logic returns the proper rendition based on what
         * was selected in the ComboBox.
         */
        private function reloadVideo():void
        {
            debug("reloadVideo");
            _videoPlayerModule.loadVideo(_videoPlayerModule.getCurrentVideo().id);
        }
        
        /**
         * Parses any choices which may have been passed into this module via
         * URL params specified in the BEML.
         */
        private function parseChoices():void
        {
            debug("parseChoices");
            
            if (loaderInfo.parameters["choices"])
            {
                _choices = [];
                var bits:Array = loaderInfo.parameters["choices"].split("|");
                for (var i:int = 0; i < bits.length; i++)
                {
                    var pieces:Array = bits[i].split(",");
                    if (pieces[1] == "-1")
                    {
                        _choices.push({label: pieces[0], low: -1, high: -1});
                    }
                    else
                    {
                        var range:Array = pieces[1].split("-");
                        _choices.push({label: pieces[0], low: range[0]*1000, high: range[1]*1000});
                    }
                }
            }
            
            if (loaderInfo.parameters["default"])
            {
                _defaultChoice = loaderInfo.parameters["default"];
            }
        }
        
        /**
         * Populates the data to be displayed in the ComboBox. If there were choices configured
         * on this module then matches are found in the list of renditions.
         */
        private function populateRenditionCombo():void
        {
            debug("populateRenditionCombo");
            
            var renditions:Array = _videoPlayerModule.getCurrentVideo().renditions;
            
            debug("renditions.length: " + renditions.length);
            
            var data:Array = [];
            
            if (renditions.length > 0 && _choices)
            {
                for (var j:int = 0; j < _choices.length; j++)
                {
                    var choice:Object = _choices[j];
                    if (choice.low == -1)
                    {
                        data.push({label: choice.label, value: -1});
                    }
                    else
                    {
                        var obj:Object = {};
                        obj.label = choice.label;
                        obj.value = [];
                        
                        for (var k:int = 0; k < renditions.length; k++)
                        {
                            var rendition:RenditionAssetDTO = RenditionAssetDTO(renditions[k]);
                            
                            if (rendition.encodingRate >= choice.low && rendition.encodingRate <= choice.high)
                            {
                                obj.value.push({encodingRate: rendition.encodingRate, index: k});
                            }
                        }
                        
                        if (obj.value.length > 0)
                        {
                            data.push(obj);
                        }
                    }
                }
            }
            
            _renditionCombo.removeEventListener(PropertyChangeEvent.CHANGE, handleRenditionComboChange);
            _renditionCombo.setData(data);
            
            if (data.length > 0)
            {
                if (_defaultChoice)
                {
                    for (var i:int = 0; i < data.length; i++)
                    {
                        if (data[i].label == _defaultChoice)
                        {
                            _renditionCombo.setSelectedIndex(i);
                            break;
                        }
                    }
                }
                else
                {
                    _renditionCombo.setSelectedIndex(0);
                }
                _renditionCombo.addEventListener(PropertyChangeEvent.CHANGE, handleRenditionComboChange);
            }
        }
        
        /**
         * @private
         */
        private function debug(message:String):void
        {
            _experienceModule.debug(message);
        }
    }
}
