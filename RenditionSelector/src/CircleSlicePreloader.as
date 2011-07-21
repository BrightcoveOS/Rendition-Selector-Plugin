package
{
    import flash.events.TimerEvent;
    import flash.events.Event;
    import flash.display.Sprite;
    import flash.display.Shape;
    import flash.utils.Timer;
    
    /**
     * Preloader animation.
     */
    public class CircleSlicePreloader 
        extends Sprite
    {
        private var _tim:Timer;
        private var _slices:int;
        private var _radius:int;
        
        /**
         * Constructor
         */
        public function CircleSlicePreloader(slices:int = 12, radius:int = 6)
        {
            _slices = slices;
            _radius = radius;
            
            draw();
            addEventListener(Event.ADDED_TO_STAGE, handleAddedToStage);
        }
        
        /**
         * @private
         */
        private function handleAddedToStage(event:Event):void
        {
            removeEventListener(Event.ADDED_TO_STAGE, handleAddedToStage);
            addEventListener(Event.REMOVED_FROM_STAGE, handleRemovedFromStage);
            
            _tim = new Timer(65);
            _tim.addEventListener(TimerEvent.TIMER, handleTimer, false, 0, true);
            _tim.start();
        }
        
        /**
         * @private
         */
        private function handleRemovedFromStage(event:Event):void
        {
            removeEventListener(Event.REMOVED_FROM_STAGE, handleRemovedFromStage);
            addEventListener(Event.ADDED_TO_STAGE, handleAddedToStage);
            
            _tim.reset();
            _tim.removeEventListener(TimerEvent.TIMER, handleTimer);
            _tim = null;
        }
        
        /**
         * @private
         */
        private function handleTimer(event:TimerEvent):void
        {
            rotation = (rotation + (360 / _slices)) % 360;
        }
        
        /**
         * @private
         */
        private function draw():void
        {
            var i:int = _slices;
            var degrees:int = 360 / _slices;
            while (i--)
            {
                var radianAngle:Number = (degrees * i) * Math.PI / 180;
                
                var slice:Shape = getSlice();
                slice.alpha = Math.max(0.2, 1 - (0.1 * i));
                slice.rotation = -degrees * i;
                slice.x = Math.sin(radianAngle) * _radius;
                slice.y = Math.cos(radianAngle) * _radius;
                
                addChild(slice);
            }
        }
        
        /**
         * @private
         */
        private function getSlice():Shape
        {
            var slice:Shape = new Shape();
            slice.graphics.beginFill(0x666666);
            slice.graphics.drawRoundRect(-1, 0, 2, _radius, 12, 12);
            slice.graphics.endFill();
            return slice;
        }
    }
}