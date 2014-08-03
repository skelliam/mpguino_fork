
// Please read Bounce2.h for information about the liscence and authors

#if defined(ARDUINO) && ARDUINO >= 100
#include "Arduino.h"
#else
#include "WProgram.h"
#endif
#include "Bounce2_mod.h"

#define DEBOUNCED_STATE 0
#define UNSTABLE_STATE  1
#define STATE_CHANGED   3

#include "mpguino.h"
#define getMillis()     millis2()  
//for this application replace millis() with millis2(), 
//because millis() is disabled 


Bounce::Bounce()
: previous_millis(0)
, interval_millis(10)
, state(0)
, pin(0)
{}

void Bounce::attach(int pin) {
 this->pin = pin;
 bool read = (bool)(digitalRead(pin) == LOW);  /* read is never used? */
 state = 0;
 if (digitalRead(pin) == LOW) {
   state = _BV(DEBOUNCED_STATE) | _BV(UNSTABLE_STATE);
 }
 #ifdef BOUNCE_LOCK-OUT
 previous_millis = 0;
 #else
 previous_millis = getMillis();
 #endif
}

void Bounce::interval(uint16_t interval_millis)
{
  this->interval_millis = interval_millis;
}

bool Bounce::update()
{
/* warning, you cannot call update() from within an interrupt, as millis() will not be available */
#ifdef BOUNCE_LOCK-OUT
    state &= ~_BV(STATE_CHANGED);
	// Ignore everything if we are locked out
	if (getMillis() - previous_millis >= interval_millis) {
		bool currentState = (bool)(digitalRead(pin) == LOW);
		if ((bool)(state & _BV(DEBOUNCED_STATE)) != currentState) {
			previous_millis = getMillis();
			state ^= _BV(DEBOUNCED_STATE);
			state |= _BV(STATE_CHANGED);
		}
	}
	return state & _BV(STATE_CHANGED);
#else
	// Lire l'etat de l'interrupteur dans une variable temporaire.
	bool currentState = (bool)(digitalRead(pin) == LOW);
    state &= ~_BV(STATE_CHANGED);

	// Redemarrer le compteur timeStamp tant et aussi longtemps que
	// la lecture ne se stabilise pas.
	if ( currentState != (bool)(state & _BV(UNSTABLE_STATE)) ) {
		previous_millis = getMillis();
		state ^= _BV(UNSTABLE_STATE);
	} else 	if ( getMillis() - previous_millis >= interval_millis ) {
		// Rendu ici, la lecture est stable
		// Est-ce que la lecture est diffÃ©rente de l'etat emmagasine de l'interrupteur?
		if ((bool)(state & _BV(DEBOUNCED_STATE)) != currentState) {
			previous_millis = getMillis();
			state ^= _BV(DEBOUNCED_STATE);
			state |= _BV(STATE_CHANGED);
		}
	}

	return state & _BV(STATE_CHANGED);
#endif
}

bool Bounce::read()
{
	return state & _BV(DEBOUNCED_STATE);
}

