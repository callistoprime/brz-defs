# RomRaider XML/DTD definitions for the gen1 Subaru BRZ / FT86 / GT86 / FR-S

## Which definitions are in this repository?

Caveats:
- I have made no particular effort to document or maintain the CEL codes in these files (e.g. P0300, U0155, etc.) and will be removing those from all files in my next update. DO NOT ATTEMPT TO DISABLE/ENABLE CEL CODES USING THESE DEFINITIONS; it could be harmless, or it could destroy your engine, I can't say for sure.

| Calibration | Modified   | Status       | Notes |
| ----------- | ---------- | ------------ | ----- |
| ZA1JS10C    | 2025-07-08 | Mostly done. | Should have parity with K00G, where possible; e.g. Base Timing logic is more complex now, some tables are gone forever, etc. SEE CELS WARNING ABOVE. |

## What are these files?

The tool 'RomRaider' uses them to open and inspect engine control files for the Subaru and Toyota vehicles, Kouki and Zenki series, with calibration IDs ZA1J____.

## Are these complete?

There's no such thing, but at the very least, I'm working towards parity with the K-series defs, and documenting whatever I find that's new or unusual along the way. There are tens of thousands parameters in this software and only a fraction of them are visible in RomRaider. I've seen many, many more in my research and it turns out that around half of them have no effect on engine behavior. My theory is that these are for rally tuning, or for the future FA24D gen2 series, or etc. Only Subaru and Toyota know, and they're not telling.

That said, I will *try* to upload definitions where I *believe* that every parameter in the definition is valid for that series; those I haven't confirmed will be commented out and noted as such in the comments. Initially, this will be S10C only, since that's the one I'm most confident in; after that will be S20G, U01A, and V00C00G in no particular order. But if you don't know how to recognize when a tuning table isn't defined correctly, you may want to take a step back and reevaluate how to proceed.

I will note in the comments at the top of each file any applicable caveats.

## Why is this repository archived?

GitHub free account restrictions offer no other way to restrict issues and pull requests. Also to forcibly set expectations around the lack of urgency I have for this work.

## Why are you doing this?

Kouki's code is more complex and the first generation of Zenki tuners seem to have moved on to other projects rather than decode it. The final era of Zenki ECU software works acceptably on Kouki cars, but the most popular tunes aren't a strict improvement out of the box like they were in the Zenki era, when installing K-series software on a B-series care made it a better vehicle.

When I was replacing my Zenki with a Kouki, the dealer tried to shaft me by 'misplacing' the 2020 BRZ I wanted to purchase and then raising the price on it by 10% while they looked for it. So I purchased a 2019 BRZ from a different dealer network and, after experimenting with the old K-series configuration, I decided that stock was better and that I'd work towards upgrading my 2019 to a 2020 instead. Six years later, I found the one-byte change necessary to make that happen; along the way, I have several work-in-progress XML definitions for the major Kouki ECU revisions.

## Zenki? Kouki? Facelift?

The first generation of this vehicle used the FA20D engine and contained two major eras of equal length; first, Zenki at launch, and then halfway through its decade, the Kouki facelift. However, Kouki was more than a facelift; it incorporated corrections for the air intake system to resolve the weaknesses revealed in Zenki, as well as ECU code upgrades specific to the intake changes, more generally updating the 'assumed' measurements of the engine's behaviors to reflect lessons learned from Zenki, as well as incorporating more advanced auto-adapt logic for timing advance, closed and open loop fueling, and direct and port injection ratios. The final ECU releases of the Zenki series, ZA1JK___, will operate on Kouki vehicles; but Kouki releases ZA1JN___ and onwards will not operate on Zenki vehicles.

## How do I request features?

It is vanishingly unlikely that I can help you. Urgency is not an option; it may be months or years between updates. Patience will be your friend.

If your current Zenki calibration is between B and K, then the K series is well-documented by others, and you should be using that. I may eventually upload my personal K definitions with the additional tables I've documented. I might even someday create a mod for K that offers the expanded table sizes from Kouki for those tuning with Zenki.

If your current Kouki calibration is between N and V and you're in the US, your choices are K-series (Zenki), S10C (Kouki), or V00C (Kouki with the 3F1/3F7 patch if pre-2020). I've focused most of my time documenting S10C as it compared to K00G, and I'm in the process of documenting V00C now.

If you want new features as a car owner, I certainly can't help you. I may choose to develop feature patches but I'm not accepting feature requests.

If you as a tuner have feedback to report, I can be located readily enough in various BRZ-adjacent places under this name.

## Why is S20G included in your work, then?

Subaru invested significant effort into improving the direct injection vs. port injection ratio configuration in the 2018 EU BRZ, most likely in response to post-VW emissions legislation; however, those improvements were not carried forward to other countries, and the more general code upgrades made in the S-series successors, U01A and V00C, were never carried forward to the EU. It is my goal to document how to apply the S20G improvements to either U01A (non-US) or V00C (US) for all Kouki facelift owners, so that my 2019 BRZ is OEM+, running the best of both worlds: the final Kouki ECU code with all lessons learned from Kouki incorporated, with the more-detailed injector ratios tune from the EU.

## What about EcuTek and BRZedit?

I know very little about them, as I haven't used either of their tuning platforms. I imagine it's up to each tuner to decide whether to alter the vehicle's existing ECU configuration or to upload their own complete replacement. This work is for those who do not have access to those more expensive, commercially-supported platforms.

## How do I bypass emissions functionality?

It is illegal in my jurisdiction for me to provide guidance or support regarding emissions bypassing. I wouldn't anyways, I put in a great deal of work to get my car to 2020 while legitimately passing the emissions tests.

## What could go wrong if I use these definitions?

I assume you could either seize your entire engine or punch a piston through the engine block, though the most likely failure is that you'll brick the ECU and have to purchase a replacement. I do my best, but you're expected to bring sensible judgment when modifying your vehicle. Recognize that you're modifying a five hundred dollar computer connected to a ten thousand dollar engine in a two ton vehicle. If you aren't prepared to deal with the adverse outcomes that are possible, leave your car alone or do business with a professional tuner instead.

THESE DEFINITIONS ARE PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THESE DEFINITIONS.

## I'm upset with you and I want to make it your problem.

### I didn't know what I was doing and I broke my car.
### I want your priorities to reflect my wants and needs.
### I have feelings and you should acknowledge them.

I did my due diligence in warning you in all capital letters above. Your actions and their outcomes are yours alone to bear. This is a free-time hobby for my own needs alone, and I do not care about yours. I'm asocial, so attempts to guilt, pressure, or humiliate me are as effective as talking to a park bench.

## Please add a LICENSE to this repository.

No.

### I want to fork this or submit pull requests.

Go for it.

### But you haven't specified what license applies.

Nope.

### I'm not comfortable working with these definitions without a license.

I celebrate your self-awareness; it's uncommon these days, and more people should be making conscious decisions about such things.

### I want to purchase a license from you.

No.
