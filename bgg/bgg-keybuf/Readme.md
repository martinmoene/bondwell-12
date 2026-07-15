<h2 id="keybuf">Bondwell 12 Keyboard Buffer</h2>

<div class="floater">The description in the source was published as an  article in Bondwell/ELCI-gg mededelingen, nummer 4, oktober 1988.<br />

<br />
Download:
<a href="kb2.mac">source</a>,
<!-- <a >listing</a>, -->
<a href="kb2.com">program</a>.
</div>
<br />

<p><span style="font-size:LARGE"></span>For the more or less experienced computer-user sooner or later it will become tiresome that he has to wait for the computer to get it's  job done and enter a new command. Nowadays many  machines are provided with a type-ahead-buffer to cope with this problem. The KEYBUF program is meant to supply the Bondwell 12 operating CP/M 2.2 with such a type-ahead-buffer. The operation of this buffer-mechanism is completely transparent to the user: it is a part of the operating system.</p>

<p>The technique used for the implementation of this keyboardbuffer is known as 'resident driver' technique.  Resident means: the driver-routines and -data reside ('sit') in memory continuously, not being damaged by the execution of any program. This is very much like the operating system parts BDOS and BIOS that  are situated somewhere in memory where they will not be disturbed by the execution of a program.<span style="font-size:LARGE"></span></p>
