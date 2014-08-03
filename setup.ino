/* This file is for the fancy UI setup screens */

#include <ScreenUi.h>
#include "LiquidCrystalExtend.h"

extern LiquidCrystalExtend mylcd;

// The next 8 methods are required to be implemented by the user of ScreenUi. These
// methods are what tie ScreenUi to your specific hardware for input and output.
// In general, these will be very similar across platforms and can probably be copied
// from one program to another and slightly modified.

// User defined method that receives input from the input method. ScreenUi calls
// this method during each update to see how the input state has changed since
// the last update. ScreenUi expects the function to fill in the values
// for x, y, selected and cancelled.
// x and y are the number of inputs in either the x or y axis since the last call
// to this method. The values can be positive or negative. A common control scheme
// for a rotary encoder would be negative y for left, positive y for right. For
// an input method consisting of the buttons on a NES control pad, for instance, might
// have the D pad control x and y, the A button control selected and the B button
// control cancelled.
void Screen::getInputDeltas(int *x, int *y, bool *selected, bool *cancelled) {
   int temp = 0;

   this->setCursorVisible(true);

   if (LeftButtonChanged() && LeftButtonPressed()) {
      temp = -1;
   }
   else if (RightButtonChanged() && RightButtonPressed()) {
      temp = 1;
   }
   
   *x = 0;
   *y = temp;
   *selected = (MiddleButtonChanged() && MiddleButtonPressed());
   *cancelled = 0;
   //Encoder.setCount(0);
}

// User defined method that clears the output device completely.
void Screen::clear() {
  mylcd.clear();
}  

// User defined method that creates a custom character in font memory. This is
// currently used by the Checkbox Component to create a nice check mark.
void Screen::createCustomChar(uint8_t slot, uint8_t *data) {
  mylcd.createChar(slot, data);
}

// User defined method that draws the given text at the given x and y position.
// The text should be drawn exactly as specified with no interpretation, scrolling
// or wrapping. 
void Screen::draw(uint8_t x, uint8_t y, const char *text) {
  mylcd.setCursor(x, y);
  mylcd.print(text);
}



// User defined method that draws the given custom character at the given x
// and y position. The custom character will be one specified to the
// Screen::createCustomChar() method.
void Screen::draw(uint8_t x, uint8_t y, uint8_t customChar) {
  mylcd.setCursor(x, y);
  mylcd.write(customChar);
}

// User defined method that turns the character cursor on or off.
void Screen::setCursorVisible(bool visible) {
  visible ? mylcd.cursor() : mylcd.noCursor();
}

// User defined method positions the character cursor.
void Screen::moveCursor(uint8_t x, uint8_t y) {
  mylcd.setCursor(x, y);
}

// User defined method that turns the blinking character on or off.
void Screen::setBlink(bool blink) {
  blink ? mylcd.blink() : mylcd.noBlink();
}

#if(0)
// Utility function for setting the brightness of the LCD. Not required for ScreenUi.
void setBright(byte val) {
  analogWrite(LCD_BRIGHT_PIN, 255 - val);
}

// Utility function for setting the contrast of the LCD. Not required for ScreenUi.
void setContrast(byte val) {
  analogWrite(LCD_CONTRAST_PIN, val);
}
#endif
