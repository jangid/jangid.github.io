---
layout: post
title:  "Colours of Web"
date:   2014-11-23 09:56:00
tags: web colours
---

Hue-Saturation-Luminosity (HSL); and not just Red-Green-Blue (RGB).

HSL is about how we think of colours. You might have observed in some of the modern CSS files that the colours are now specified as hsl(hue, saturation, luminosity) instead of rgb(red, green, blue). I was going through various colour guides and have come up this with this summary.

Hue
---

Hue is the actual selection of colour that we want. The other two values has nothing to do with the shade selection. On a dial from 0° to 360° the colour varies from red, violet to red again i.e. the rainbow colours.

![Yellow at 60º](/assets/img/2014/11/23/yellow_at_60.jpg "Yellow at 60º")
*Yellow at 60º*

I use YUI Colur Picker to decide the colours on my pages and screens. You may use any other, lots of them on GitHub.

![Blue at 240º](/assets/img/2014/11/23/blue_at_240.jpg "Blue at 240º")
*Blue at 240º*

At 60° hue it is yellow and 240° blue. Once you have zeroed in on which shade you want move on to the next parameter i.e. saturation.

Saturation
----------

I think of saturation in term of colour’s age. A blue, or for the context any coloured, object getting older and older will fade in colour and ultimately turn grey.

![Yellow at 0º Saturation](/assets/img/2014/11/23/yellow_at_0_saturation.jpg "Yellow at 0º Saturation")
*Yellow at 0º Saturation*

![Blue at 0º Saturation](/assets/img/2014/11/23/blue_at_0_saturation.jpg "Blue at 0º Saturation")
*Blue at 0º Saturation*

It doesn’t matter which colour is selected (hue). When the saturation is 0% it will look grey. And when the saturation is 100% the colour has full intensity; like a brand new object.

Luminosity
----------

Have you ever entered in a darkroom, where no light can enter. Not very long ago, photographers used to process the photos in a darkroom. In a darkroom, in absence of light all colours look same — black.

Remember the analog brightness control in colour televisions. If you turn the knob full clockwise everything turns white.

![Blue at 0º Luminosity](/assets/img/2014/11/23/blue_at_0_luminosity.jpg "Blue at 0º Luminosity")
*Blue at 0º Luminosity*

![Blue at 100º Luminosity](/assets/img/2014/11/23/blue_at_100_luminosity.jpg "Blue at 100º Luminosity")
*Blue at 100º Luminosity*

I think of luminosity in the same way i.e. how much white light is falling on the object. It does not matter what hue you have selected or what saturation you have set the object will look black when luminosity is 0% i.e. no light and it will look white when it is 100% i.e. full bright.

I find this analogy easier because thinking in terms of red-green-blue is not very natural. We don’t know exactly what combination red, green and blue to use to produce a certain colour. But our mind can comprehend colour, intensity and brightness much easily.

I hope you enjoyed; so next time use hsl() in your CSS.
