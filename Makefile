# (c) 2020, Maksymilian Mruszczak <u at one u x dot o r g>

.SUFFIXES: .hex .S
.PHONY: flash clean

flash: snake.hex
	avrdude -c arduino -p atmega328p -P /dev/ttyUSB0 -U flash:w:$<

.S.hex:
	avr-gcc -Os -DF_CPU=8000000 -mmcu=atmega328p -c $< -o tmp.o
	avr-gcc -DF_CPU=8000000 -mmcu=atmega328p -o tmp.elf tmp.o
	avr-objcopy --change-section-lma .eeprom=0 -O ihex tmp.elf $@
	rm tmp.elf

clean:
	rm *.o *.elf *.hex
