package
{
    import flash.display.Sprite;
    import flash.events.Event;
    import flash.events.TimerEvent;
    import flash.utils.Dictionary;
    import flash.utils.Timer;
	
	public class Spinner 
	   extends Sprite
    {
        private var _callLaterMethods:Dictionary = new Dictionary();
        private var _inCallLaterPhase:Boolean = false;
		private var _fadeTimer:Timer;
		private var _isPlaying:Boolean;
		private var _numTicks:int = 12;
		private var _size:Number = 30;
		private var _tickWidth:Number = 3;
		private var _tickColor:uint = 0xEAEAEA;
		private var _speed:int = 800;
		
		/**
		 * Constructor
		 */
		public function Spinner()
		{
		    start();
		    invalidate();
		}
		
		/**
		 * Starts the spinner.
		 */
		public function start():void
        {
            if (isPlaying) return;
            
            _fadeTimer = new Timer(speed/numTicks);
            _fadeTimer.addEventListener(TimerEvent.TIMER, handleFadeTimer);
            _fadeTimer.start();
            
            _isPlaying = true;
        }
        
        /**
         * Stops the spinner.
         */
        public function stop():void
        {
            if (!isPlaying) return;
            
            _fadeTimer.removeEventListener(TimerEvent.TIMER, handleFadeTimer);
            _fadeTimer.stop();
            _fadeTimer = null;
            _isPlaying = false;
        }
		
		/**
		 * @private
		 */
		private function updateDisplay():void
		{
		    var wasPlaying:Boolean = isPlaying;
		    
		    stop();
		    
		    while (numChildren > 0)
		    {
		        removeChildAt(numChildren-1);
		    }
		    
		    var radius:Number = size / 2;
		    var angle:Number = 2 * Math.PI/numTicks;
		    var currentAngle:Number = 0;
		    
		    for (var i:int = 0; i < numTicks; i++)
		    {
		        var xStart:Number = radius + Math.sin(currentAngle) * ((numTicks + 2) * tickWidth / 2 / Math.PI);
		        var yStart:Number = radius - Math.cos(currentAngle) * ((numTicks + 2) * tickWidth / 2 / Math.PI);
		        var xEnd:Number = radius + Math.sin(currentAngle) * (radius - tickWidth);
		        var yEnd:Number = radius - Math.cos(currentAngle) * (radius - tickWidth);
		        
		        var tick:Tick = new Tick(xStart, yStart, xEnd, yEnd, tickWidth, tickColor);
		        tick.alpha = 0.1;
		        addChild(tick);
		        
		        currentAngle += angle;
		    }
		    
		    if (wasPlaying)
		    {
		        start();
		    }
		}
		
		/**
		 * @private
		 */
		private function handleFadeTimer(event:TimerEvent):void
		{
		    var index:int = int(_fadeTimer.currentCount % numTicks);
		    if (numChildren > index)
		    {
		        var tick:Tick = getChildAt(index) as Tick;
		        tick.fade();
		    }
		}
		
		/**
		 * The overall diameter of the spinner; also the height and width.
		 */
		public function set size(value:Number):void 
		{
			if (value != _size) 
			{
				_size = value;
                invalidate();
			}
		}
		
		/**
		 * @private
		 */
		public function get size():Number 
		{
			return _size;
		}
		
		/**
		 * The number of "spokes" on the spinner.
		 */
		public function set numTicks(value:int):void 
		{
			if (value != _numTicks) 
			{
				_numTicks = value;
                invalidate();
			}
		}
		
		/**
         * @private
         */
		public function get numTicks():int 
		{
			return _numTicks;
		}
		
		/**
		 * The width of the "spokes" on the spinner.
		 */
		public function set tickWidth(value:int):void 
		{
			if (value != _tickWidth) 
			{
				_tickWidth = value;
				invalidate();
			}
		}
		
		/**
         * @private
         */
		public function get tickWidth():int 
		{
			return _tickWidth;
		}
		
		/**
         * The color of the "spokes" on the spinner.
         */
        public function set tickColor(value:uint):void 
        {
            if (value != _tickColor) 
            {
                _tickColor = value;
                invalidate();
            }
        }
        
        /**
         * @private
         */
        public function get tickColor():uint 
        {
            return _tickColor;
        }
		
		/**
		 * The duration (in milliseconds) that it takes for the spinner to make one revolution.
		 */
		public function set speed(value:int):void 
		{
			if (value != _speed) 
			{
				_speed = value;
				
				if (isPlaying) 
				{
					_fadeTimer.stop();
					_fadeTimer.delay = _speed / _numTicks;
					_fadeTimer.start();
				}
			}
		}
		
		/**
         * @private
         */
		public function get speed():int 
		{
			return _speed;
		}
		
		/**
		 * Indicates whether the spinner is playing or not.
		 */
		public function get isPlaying():Boolean 
		{
			return _isPlaying;
		}
		
		/**
         * Marks a property as invalid and redraws the component on the next frame.
         */
        public function invalidate():void
        {
            callLater(updateDisplay);
        }
        
        /**
         * @private
         */
        private function callLater(method:Function):void
        {
            if (_inCallLaterPhase)
            {
                return;
            }
            
            _callLaterMethods[method] = true;
            addEventListener(Event.ENTER_FRAME, callLaterDispatcher);
        }
        
        /**
         * @private
         */
        private function callLaterDispatcher(event:Event):void
        {
            removeEventListener(Event.ENTER_FRAME, callLaterDispatcher);
            
            _inCallLaterPhase = true;
            
            var methods:Dictionary = _callLaterMethods;
            for (var method:Object in methods)
            {
                method();
                delete(methods[method]);
            }
            
            _inCallLaterPhase = false;
        }
	}
}

import flash.display.Sprite;
import flash.events.Event;
import flash.utils.getTimer;
import flash.utils.Timer;
import flash.events.TimerEvent;
    
class Tick
    extends Sprite
{
    private var _tim:Timer;
    
    /**
     * Constructor
     */
    public function Tick(fromX:Number, fromY:Number, toX:Number, toY:Number, tickWidth:int, tickColor:uint) 
    {
        graphics.lineStyle(tickWidth, tickColor, 1.0, false, "normal", "rounded");
        graphics.moveTo(fromX, fromY);
        graphics.lineTo(toX, toY);
        
        _tim = new Timer(100);
        _tim.addEventListener(TimerEvent.TIMER, handleTimer);
    }
    
    /**
     * @private
     */
    public function fade():void 
    {
        alpha = 1;
        
        if (!_tim.running)
        {
            _tim.start();
        }
    }
    
    /**
     * @private
     */
    private function handleTimer(event:TimerEvent):void
    {
        alpha -= 0.05;
        if (alpha <= 0.1)
        {
            _tim.stop();
        }
    }
}