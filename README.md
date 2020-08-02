-------------------------------------------------------------------------------------------------------------
Placeable Buckets for Catching Rainwater
[placeable_buckets]
-------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------
About
-------------------------------------------------------------------------------------------------------------
This mod overrides buckets from the buckets mod, so that they can be placed on the ground. These buckets come with a variety of optional features:
* Catching rainwater over time, which may be useful for situations where easy water renewing is disabled. Requires climate_api.
* Liquid source nodes will fall into an empty bucket if it's above one.
* Water will cool lava buckets, at which point they turn into either a block of obsidian or a block of stone.
* Lava will vaporize any water in nearby buckets.
* Items thrown into full lava buckets will be incinerated. Requires entitycontrol.
* Empty and water buckets can be used as inlets for pipe networks from the waterworks mod.

-------------------------------------------------------------------------------------------------------------
Dependencies and Support
-------------------------------------------------------------------------------------------------------------
Hard dependencies:
* bucket
* default

Soft dependencies:
* climate_api, to allow humid weather to slowly fill empty buckets with water.
* entitycontrol, to override item entities so that they are incinerated upon landing on lava buckets.
* waterworks, in which empty and water buckets can be used as inlets. Requires my fork, which modifies the api to allow liquid in inlets to be transported.

-------------------------------------------------------------------------------------------------------------
License
-------------------------------------------------------------------------------------------------------------
The LGPL v2.1 License is used with this mod. See https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html or LICENSE.txt for more details.

-------------------------------------------------------------------------------------------------------------
Installation
-------------------------------------------------------------------------------------------------------------
Download, unzip, and place within the usual minetest/current/mods folder, and it will behave in relation to the Minetest engine like any other mod.
