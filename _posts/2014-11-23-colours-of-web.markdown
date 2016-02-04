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

<a data-flickr-embed="true"  data-footer="true" href="https://www.flickr.com/photos/jangid/24690045272/in/album-72157664212186746/" title="Yellow at 60°"><img src="https://farm2.staticflickr.com/1511/24690045272_492637cd11.jpg" width="450" height="160" alt="Yellow at 60°"></a><script async src="//embedr.flickr.com/assets/client-code.js" charset="utf-8"></script>

I use YUI Colur Picker to decide the colours on my pages and screens. You may use any other, lots of them on GitHub.

<a data-flickr-embed="true"  data-footer="true" href="https://www.flickr.com/photos/jangid/24781646176/in/album-72157664212186746/" title="Blue at 240°"><img src="https://farm2.staticflickr.com/1503/24781646176_f63dd862a5.jpg" width="450" height="160" alt="Blue at 240°"></a><script async src="//embedr.flickr.com/assets/client-code.js" charset="utf-8"></script>

At 60° hue it is yellow and 240° blue. Once you have zeroed in on which shade you want move on to the next parameter i.e. saturation.

Saturation
----------

I think of saturation in term of colour’s age. A blue, or for the context any coloured, object getting older and older will fade in colour and ultimately turn grey.

<a data-flickr-embed="true"  data-footer="true" href="https://www.flickr.com/photos/jangid/24512391190/in/album-72157664212186746/" title="Yellow at 0% saturation"><img src="https://farm2.staticflickr.com/1539/24512391190_456abd4d1b.jpg" width="450" height="160" alt="Yellow at 0% saturation"></a><script async src="//embedr.flickr.com/assets/client-code.js" charset="utf-8"></script>

<a data-flickr-embed="true"  data-footer="true" href="https://www.flickr.com/photos/jangid/24690074462/in/album-72157664212186746/" title="Blue at 0% saturation"><img src="https://farm2.staticflickr.com/1545/24690074462_e994d1075e.jpg" width="450" height="160" alt="Blue at 0% saturation"></a><script async src="//embedr.flickr.com/assets/client-code.js" charset="utf-8"></script>

It doesn’t matter which colour is selected (hue). When the saturation is 0% it will look grey. And when the saturation is 100% the colour has full intensity; like a brand new object.

Luminosity
----------

Have you ever entered in a darkroom, where no light can enter. Not very long ago, photographers used to process the photos in a darkroom. In a darkroom, in absence of light all colours look same — black.

Remember the analog brightness control in colour televisions. If you turn the knob full clockwise everything turns white.

<a data-flickr-embed="true" data-footer="true"  href="https://www.flickr.com/photos/jangid/24690083342/in/album-72157664212186746/" title="Blue at 0% luminosity"><img src="https://farm2.staticflickr.com/1654/24690083342_b08d1e617a.jpg" width="450" height="160" alt="Blue at 0% luminosity"></a><script async src="//embedr.flickr.com/assets/client-code.js" charset="utf-8"></script>

<a data-flickr-embed="true" data-footer="true" href="https://www.flickr.com/photos/jangid/24512408330/in/album-72157664212186746/" title="Blue at 100% luminosity"><img src="https://farm2.staticflickr.com/1540/24512408330_07d2aac02f.jpg" width="450" height="160" alt="Blue at 100% luminosity"></a><script async src="//embedr.flickr.com/assets/client-code.js" charset="utf-8"></script>

I think of luminosity in the same way i.e. how much white light is falling on the object. It does not matter what hue you have selected or what saturation you have set the object will look black when luminosity is 0% i.e. no light and it will look white when it is 100% i.e. full bright.

I find this analogy easier because thinking in terms of red-green-blue is not very natural. We don’t know exactly what combination red, green and blue to use to produce a certain colour. But our mind can comprehend colour, intensity and brightness much easily.

I hope you enjoyed; so next time use hsl() in your CSS.
