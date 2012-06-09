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
    
    import flash.display.Graphics;
    import flash.display.Sprite;
    import flash.display.Stage;
    import flash.events.TimerEvent;
    import flash.utils.Timer;
    
    /**
     * Rendition selector.
     * 
     * Populates a ComboBox in BEML named "renditionCombo", displaying various
     * choices for rendition quality selection. The format for specifying 
     * choices is as follows:
     * 
     * RenditionSelector.swf?choices=AUTO,-1|HD,2200-3000|HIGH,1500-1800|MED,700-1000|LOW,300-400&default=MED&spinner=true&spinnerbg=false
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
     * 
     * The param "spinner" toggles the visibility of a loading
     * spinner which appears during rendition changes.
     * 
     * The param "spinnerbg" toggles the background that appears
     * along with the spinner icon.
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
        
        /**
         * Loader/overlay - overview
         * 
         * When the Brightcove player changes rendition it needs to seek to the current position.
         * Due to a limitation in Adobe's NetStream, the Brightcove player cannot seek until it 
         * has begun playback. As a consequence, the Brightcove player does a fast play/pause while
         * changing renditions. For that reason, we need to hide the video and mute the audio
         * during this time. 
         */ 
        private var _stage:Stage;                       // we keep a reference to the stage
        private var _overlay:Sprite;                    // this is the main overlay, which holds a reference to the spinner
        private var _spinner:Spinner;                   // the spinner that belongs to the sprite
        private var _volume:Number;                     // we mute the volume when 
        private var _loaderVisible:Boolean = false;     // whether or not the overlay is on the stage (avoid possible exception)
        private var _waitForTimer:Boolean = false;      // whether or not the loader was shown during paused playback
        
        
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
            
            _stage = _experienceModule.getStage();  
            
            if (loaderInfo.parameters["spinner"] && loaderInfo.parameters["spinner"] == "true")
            {
                _overlay = new Sprite();
                
                _spinner = new Spinner();
                _overlay.addChild(_spinner);
                
                drawOverlay();
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
            
            //we need to reset things when the rendition switch is complete
            _videoPlayerModule.addEventListener(MediaEvent.RENDITION_CHANGE_COMPLETE, handleRenditionChangeComplete);
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
                //Check for selection (-1 value) before assigning to array to avoid TypeError
				if( _renditionCombo.getSelectedData().value != -1 )
				{
					var renditions:Array = _renditionCombo.getSelectedData().value;
	                for (var i:int = 0; i < renditions.length; i++)
	                {
	                    var rendition:Object = renditions[i];
	                    
	                    // if this is the last rendition for the choice or if the detected
	                    // bandwidth is higher than the rendition's encoding rate
	                    // then return that rendition's index
	                    // this works because the renditions for a particular choice 
	                    // are ordered by highest to lowest bit rate
	                    if ((context.detectedBandwidth * 1024) >= rendition.encodingRate ||
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
            }
            return -1;
        }
        
        /**
         * When the rendition is finished switching we will unhide the loader
         */ 
        private function handleRenditionChangeComplete(event:MediaEvent):void
        {
            if (!_waitForTimer)
            {
                // we only do this if the video was playing
                // otherwise there is a timer that will hide it
                hideLoader();
            }
        }
        
        /**
         * Thus function will hide the loader when the timer goes off
         * The reason a timer is used is to hide the sometimes visible
         * first few frames of the video, due to limitations of the 
         * netstream's seek function
         */ 
        private function handleHideLoaderTimer(event:TimerEvent):void
        {
            hideLoader();
            _waitForTimer = false;
        }
        
        /**
         * Hide the loader that is drawn onto the stage
         */
        private function hideLoader():void 
        {
            if (_loaderVisible)
            {
                // restore the volume to where it was before rendition change
                _videoPlayerModule.setVolume(_volume);
                
                // hide the overlay and spinner
                _stage.removeChild(_overlay);
                _experienceModule.setEnabled(true);
                _loaderVisible = false;
                
            }
        }

        /**
         * Shows the loader that is drawn onto the stage
         */
        private function showLoader():void
        {
            _loaderVisible = true;
            
            // we need to store away the volume
            _volume = _videoPlayerModule.getVolume();
            _videoPlayerModule.setVolume(0); 
             
            // add the overlay/spinner
            drawOverlay();
            _stage.addChild(_overlay);
            _experienceModule.setEnabled(false);   
        }
        
        /**
         * @private
         */
        private function drawOverlay():void
        {
            _spinner.x = Math.round(_stage.width / 2 - _spinner.width / 2);
            _spinner.y = Math.round(_stage.height / 2 - _spinner.height / 2);
            
            if (loaderInfo.parameters["spinnerbg"] && loaderInfo.parameters["spinnerbg"] == "true")
            {
                var g:Graphics = _overlay.graphics;
                g.beginFill(0x000000);
                g.lineStyle(1, 0x000000);
                g.drawRect(0, 0, _stage.width, _stage.height);
                g.endFill();
            }
        }
        
        /**
         * Handles any selections made on the ComboBox.
         */
        private function handleRenditionComboChange(event:PropertyChangeEvent):void
        {
            debug("handleRenditionComboChange");
            if (event.property == "selectedItem") 
            {
                // only display the spinner overlay if needed
                if (_overlay)
                {
                    showLoader();
                        
                    if (!_videoPlayerModule.isPlaying()){
                        _waitForTimer = true;
                        // if we are not playing, hide the loader after .5 sec
                        var timer:Timer = new Timer(500, 1);
                        timer.addEventListener(TimerEvent.TIMER, handleHideLoaderTimer);
                        timer.start();
                    }
                }
                
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
    		
			renditions.sortOn("encodingRate",Array.NUMERIC | Array.DESCENDING);
            
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
