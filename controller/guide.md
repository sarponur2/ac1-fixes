# F710 controller mapping

Observed symptom: LT/RT moved the camera instead of performing the expected actions.

## Start with the controller mode

The Logitech F710 supports XInput (`X`) and DirectInput (`D`). Close the game and set the hardware switch to **X**, then turn on the controller and relaunch. [Logitech's mode-switch instructions](https://support.logi.com/hc/en-ch/articles/360023400073-Using-the-input-mode-switch-on-the-F710-to-select-DirectInput-or-XInput).

XInput provides a standard Xbox-style layout, including separate trigger values. Older joystick handling can interpret axes differently. The trigger symptom is consistent with a mapping mismatch, but it alone does not prove the exact original cause. [Microsoft's comparison](https://learn.microsoft.com/en-us/windows/win32/xinput/xinput-and-directinput).

## Existing public option: EaglePatchAC1

[Sergeanur's EaglePatch](https://github.com/Sergeanur/EaglePatch) documents support for all XInput controllers and simultaneous keyboard/mouse and gamepad input. Follow the original author's AC1 installation instructions and [release downloads](https://github.com/Sergeanur/EaglePatch/releases). AC1 and AC2 have different packages and features.

Back up existing mod files before adding a loader. An existing `dinput8.dll` may belong to another mod; do not overwrite it blindly. The original EaglePatch includes features beyond the controller fix.

## What the local controller-only experiment did

A private local build reused the controller part of EaglePatch commit `a39dc87`, together with a small local DirectInput proxy. The proxy forwarded `DirectInput8Create` to Windows and installed two guarded redirects in AC1's running memory: Xbox-style pad creation and input updating. The original game already contains Xbox input code.

Both keyboard/mouse and gamepad were updated, switching to the active device. This behavior removed the need to manually select a controller in settings for the tested setup.

Tested setup: Windows 10, the supported Steam DX10 executable, Logitech F710 on X with its wireless dongle, controller slot 0, default KeyboardMouse2 layout. The user confirmed working keyboard/mouse, then returned for a gameplay test and reported that everything seemed to work.

Other controllers, multiple controllers, alternate keyboard layouts and disconnect/reconnect behavior have not been comprehensively tested. The original public EaglePatch is a separate product with its own documented supported versions.

## Availability of the custom build

The custom DLL, copied upstream source and build package are **not distributed here**. The main EaglePatch controller code's redistribution permission has not been established. This guide credits and links the upstream author instead of repackaging that code. A license on a bundled helper does not establish a license for the controller implementation.

## Gameplay check

Check right-stick camera movement, independent LT/RT actions, left-stick movement, face buttons, and switching back to keyboard/mouse. Test in actual gameplay; cinematics may not accept the same inputs.

For the private local experiment, exiting AC1 and removing only its installed local `dinput8.dll` removes that controller patch. That instruction applies to that custom build, not to any unrelated DLL supplied by another mod. Its separate executable-based startup repair remains in place.
