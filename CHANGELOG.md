# Changelog

## Version 0.5.2

Date Range 3/9/21 - 3/31/21

- Fixed [#190]( https://github.com/urbanopt/urbanopt-cli/issues/190 ), Graceful rescue from "uo" command
- Fixed [#191]( https://github.com/urbanopt/urbanopt-cli/issues/191 ), add error catching
- Fixed [#197]( https://github.com/urbanopt/urbanopt-cli/issues/197 ), Update copyrights for 2021
- Fixed [#200]( https://github.com/urbanopt/urbanopt-cli/issues/200 ), Scenario Level Assumptions File cannot be Defined by User
- Fixed [#202]( https://github.com/urbanopt/urbanopt-cli/issues/202 ), Use the new Ditto-Reader CLI in the UO CLI - Remove Pycall Dependency
- Fixed [#214]( https://github.com/urbanopt/urbanopt-cli/issues/214 ), reopt-scenario processing should allow selecting assumptions file
- Fixed [#215]( https://github.com/urbanopt/urbanopt-cli/issues/215 ), Support running GMT (DES) directly from the main CLI
- Fixed [#219]( https://github.com/urbanopt/urbanopt-cli/issues/219 ), Avoid saving feature reports twice.

## Version 0.5.1

Date Range 12/17/20 - 3/8/21

- Fixed [#157]( https://github.com/urbanopt/urbanopt-cli/issues/157 ), Edit maximum value for y axis in visualization graphs
- Fixed [#158]( https://github.com/urbanopt/urbanopt-cli/issues/158 ), Check units for Gas:Facility in visualization graphs
- Fixed [#172]( https://github.com/urbanopt/urbanopt-cli/issues/172 ), Add district heating/cooling systems
- Fixed [#174]( https://github.com/urbanopt/urbanopt-cli/issues/174 ), Ditto reader doesn't work in a virtualenv
- Fixed [#175]( https://github.com/urbanopt/urbanopt-cli/issues/175 ), developer_nrel_key warning at each user command
- Fixed [#176]( https://github.com/urbanopt/urbanopt-cli/issues/176 ), validate eui results
- Fixed [#183]( https://github.com/urbanopt/urbanopt-cli/issues/183 ), Add EV charging measure to example project
- Fixed [#184]( https://github.com/urbanopt/urbanopt-cli/issues/184 ), Change fuel units to kBtus on the monthly and net charts
- Fixed [#187]( https://github.com/urbanopt/urbanopt-cli/issues/187 ), Tests shouldn't take so long
- Fixed [#192]( https://github.com/urbanopt/urbanopt-cli/issues/192 ), Add electrical components to feature-file to work with opendss
- Fixed [#199]( https://github.com/urbanopt/urbanopt-cli/issues/199 ), re-added the multifamily options to the commercial_building_types list.
- Fixed [#200]( https://github.com/urbanopt/urbanopt-cli/issues/200 ), Scenario Level Assumptions File cannot be Defined by User
- Fixed [#201]( https://github.com/urbanopt/urbanopt-cli/issues/201 ), OpenDSS should work with URBANopt
- Fixed [#202]( https://github.com/urbanopt/urbanopt-cli/issues/202 ), Use the new Ditto-Reader CLI in the UO CLI - Remove Pycall Dependency
- Fixed [#203]( https://github.com/urbanopt/urbanopt-cli/issues/203 ), Update CI to install Python and urbanopt-ditto-reader package

## Version 0.5.0

Date Range 11/17/20 - 12/16/20

- Updated dependencies to support OpenStudio 3.1.0

## Version 0.4.1

Date Range: 10/01/20 - 11/16/20

- Fixed [#146]( https://github.com/urbanopt/urbanopt-cli/issues/146 ), Better error handling on Visualize command
- Fixed [#147]( https://github.com/urbanopt/urbanopt-cli/issues/147 ), Copy Visualize files from directory
- Fixed [#151]( https://github.com/urbanopt/urbanopt-cli/issues/151 ), Saving to db file doesn't work right on windows machines
- Fixed [#153]( https://github.com/urbanopt/urbanopt-cli/issues/153 ), Dependencies need to be managed tighter
- Fixed [#156]( https://github.com/urbanopt/urbanopt-cli/issues/156 ), BUGFIX: Add methods to save feature results
- Fixed [#163]( https://github.com/urbanopt/urbanopt-cli/issues/163 ), Bugfixes for residential workflow
- Fixed [#164]( https://github.com/urbanopt/urbanopt-cli/issues/164 ), Enhancements for residential workflow

## Version 0.4.0

Date Range: 06/11/20 - 09/30/20

- Fixed [#49]( https://github.com/urbanopt/urbanopt-cli/issues/49 ), Gathering results (post-processing) should provide scenario-level results in a database file
- Fixed [#95]( https://github.com/urbanopt/urbanopt-cli/issues/95 ), store bundle directory outside of project directory
- Fixed [#115]( https://github.com/urbanopt/urbanopt-cli/issues/115 ), Add command for visualising scenario results after post processing
- Fixed [#117]( https://github.com/urbanopt/urbanopt-cli/issues/117 ), run results
- Fixed [#119]( https://github.com/urbanopt/urbanopt-cli/issues/119 ), Integrate OpenDSS/diTTo reader
- Fixed [#121]( https://github.com/urbanopt/urbanopt-cli/issues/121 ), Add command for visualising feature results after post processing
- Fixed [#123]( https://github.com/urbanopt/urbanopt-cli/issues/123 ), Check that regular run completed before attempting opendss run
- Fixed [#124]( https://github.com/urbanopt/urbanopt-cli/issues/124 ), Add alternate geometry creation methods to cli
- Fixed [#129]( https://github.com/urbanopt/urbanopt-cli/issues/129 ), Need better way of getting data files into project folders
- Fixed [#131]( https://github.com/urbanopt/urbanopt-cli/issues/131 ), Implement HPXML-based workflow for residential buildings
- Fixed [#134]( https://github.com/urbanopt/urbanopt-cli/issues/134 ), Update runner.conf with new options
- Fixed [#136]( https://github.com/urbanopt/urbanopt-cli/issues/136 ), Chore: Add TM to first mention URBANopt on LICENSE file and LICENSE section
- Fixed [#138]( https://github.com/urbanopt/urbanopt-cli/issues/138 ), Update reopt assumption file in example projects and CLI repos.
- Fixed [#140]( https://github.com/urbanopt/urbanopt-cli/issues/140 ), db file is only created for default post-processor
- Fixed [#143]( https://github.com/urbanopt/urbanopt-cli/issues/143 ), Restrict scenario CSV names to be all lowercase

## Version 0.3.1

Date Range: 06/05/20 - 06/10/20:

- Fixed [#113]( https://github.com/urbanopt/urbanopt-cli/issues/113 ), CLI crashes if reopt folder missing from project directory

## Version 0.3.0

Date Range: 04/23/20 - 06/05/20

- Fixed [#96]( https://github.com/urbanopt/urbanopt-cli/issues/96 ), Better error checking
- Fixed [#99]( https://github.com/urbanopt/urbanopt-cli/issues/99 ), CLI complexity is hindering usage
- Fixed [#100]( https://github.com/urbanopt/urbanopt-cli/issues/100 ), REopt gem is used even for non-reopt simulations and post-processing
- Fixed [#102]( https://github.com/urbanopt/urbanopt-cli/issues/102 ), Update change_log functionality
- Fixed [#103]( https://github.com/urbanopt/urbanopt-cli/issues/103 ), Update CLI to work with OS 3.0

Update to OpenStudio 3.x and Ruby 2.5.x

## Version 0.2.3

Date Range: 04/01/20 - 04/23/20:

- Fixed [#65]( https://github.com/urbanopt/urbanopt-cli/issues/65 ), Add more tests
- Fixed [#81]( https://github.com/urbanopt/urbanopt-cli/issues/81 ), Mappers weren't updated for version 0.2
- Fixed [#83]( https://github.com/urbanopt/urbanopt-cli/issues/83 ), Recommend using absolute paths
- Fixed [#85]( https://github.com/urbanopt/urbanopt-cli/issues/85 ), reopt dependency not installed
- Fixed [#88]( https://github.com/urbanopt/urbanopt-cli/issues/88 ), Reopt tests are failing
- Fixed [#90]( https://github.com/urbanopt/urbanopt-cli/issues/90 ), Update baseline mapper
- Fixed [#92]( https://github.com/urbanopt/urbanopt-cli/issues/92 ), baseline mapper bug reading json file

## Version 0.2.2

Date Range: 3/31/20 - 3/31/20

- Fixing simplecov / json native extension dependency

## Version 0.2.1

Date Range: 03/31/20 - 03/31/20

- Fixed [#77]( https://github.com/urbanopt/urbanopt-cli/issues/77 ), Undefined local variable

## Version 0.2.0

Date Range: 02/14/20 - 03/31/20

- Fixed [#2]( https://github.com/urbanopt/urbanopt-cli/issues/2 ), Feature Request: Have this gem get pre-installed
- Fixed [#4]( https://github.com/urbanopt/urbanopt-cli/issues/4 ), Remove example-geojson-project repo
- Fixed [#9]( https://github.com/urbanopt/urbanopt-cli/issues/9 ), Update copyrights
- Fixed [#10]( https://github.com/urbanopt/urbanopt-cli/issues/10 ), Add --version flag
- Fixed [#12]( https://github.com/urbanopt/urbanopt-cli/issues/12 ), Support ReOpt workflow
- Fixed [#16]( https://github.com/urbanopt/urbanopt-cli/issues/16 ), Remove travis file
- Fixed [#19]( https://github.com/urbanopt/urbanopt-cli/issues/19 ), Rack version must be <2.2
- Fixed [#20]( https://github.com/urbanopt/urbanopt-cli/issues/20 ), Simplecov is an unnecessary dependency
- Fixed [#22]( https://github.com/urbanopt/urbanopt-cli/issues/22 ), Run a single datapoint
- Fixed [#25]( https://github.com/urbanopt/urbanopt-cli/issues/25 ), Add ability for CLI to generate config file
- Fixed [#26]( https://github.com/urbanopt/urbanopt-cli/issues/26 ), Using weekday start time in example mapper
- Fixed [#39]( https://github.com/urbanopt/urbanopt-cli/issues/39 ), PR template shouldn't ask for Changelog updates
- Fixed [#40]( https://github.com/urbanopt/urbanopt-cli/issues/40 ), Windows users are requiring Rack during Run command
- Fixed [#42]( https://github.com/urbanopt/urbanopt-cli/issues/42 ), We still need to require the NREL fork of Simplecov
- Fixed [#43]( https://github.com/urbanopt/urbanopt-cli/issues/43 ), rake install is hanging
- Fixed [#44]( https://github.com/urbanopt/urbanopt-cli/issues/44 ), Add detailed OSM workflow to example project
- Fixed [#45]( https://github.com/urbanopt/urbanopt-cli/issues/45 ), Remove single-family and multi-family buildings from example project
- Fixed [#46]( https://github.com/urbanopt/urbanopt-cli/issues/46 ), Remove os-standard dependency from example project gemfile
- Fixed [#55]( https://github.com/urbanopt/urbanopt-cli/issues/55 ), SegFault running CLI on windows
- Fixed [#56]( https://github.com/urbanopt/urbanopt-cli/issues/56 ), Ruby version is not specified
- Fixed [#59]( https://github.com/urbanopt/urbanopt-cli/issues/59 ), Add save individual report functionality to CLI
- Fixed [#63]( https://github.com/urbanopt/urbanopt-cli/issues/63 ), Add a way to create an "empty" project
- Fixed [#67]( https://github.com/urbanopt/urbanopt-cli/issues/67 ), Add an option to the -p command to overwrite an existing directory
- Fixed [#68]( https://github.com/urbanopt/urbanopt-cli/issues/68 ), Add OpenDSS postprocess command

## Version 0.1.0

Initial commit
