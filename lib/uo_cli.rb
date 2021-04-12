#!/usr/bin/ ruby

# *********************************************************************************
# URBANopt™, Copyright (c) 2019-2021, Alliance for Sustainable Energy, LLC, and other
# contributors. All rights reserved.

# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:

# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.

# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.

# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.

# Redistribution of this software, without modification, must refer to the software
# by the same designation. Redistribution of a modified version of this software
# (i) may not refer to the modified version by the same designation, or by any
# confusingly similar designation, and (ii) must refer to the underlying software
# originally provided by Alliance as “URBANopt”. Except to comply with the foregoing,
# the term “URBANopt”, or any confusingly similar designation may not be used to
# refer to any modified version of this software or any modified version of the
# underlying software originally provided by Alliance without the prior written
# consent of Alliance.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************

require 'uo_cli/version'
require 'optimist'
require 'urbanopt/geojson'
require 'urbanopt/scenario'
require 'urbanopt/reopt'
require 'urbanopt/reopt_scenario'
require 'csv'
require 'fileutils'
require 'json'
require 'openssl'
require 'open3'
require 'yaml'

module URBANopt
  module CLI
    class UrbanOptCLI
      COMMAND_MAP = {
        'create' => 'Make new things - project directory or files',
        'run' => 'Use files in your directory to simulate district energy use',
        'opendss' => 'Run OpenDSS simulation',
        'process' => 'Post-process URBANopt simulations for additional insights',
        'visualize' => 'Visualize and compare results for features and scenarios',
        'validate' => 'Validate results with custom rules',
        'delete' => 'Delete simulations for a specified scenario',
        'des_params' => 'Make a DES system parameters config file',
        'des_create' => 'Create a Modelica model',
        'des_run' => 'Run a Modelica DES model'
      }.freeze

      def initialize
        @subopts = nil
        @command = nil
        @mainopts = Optimist.options do
          version VERSION
          banner "\nURBANopt CLI version: #{version}"
          banner "\nUsage:"
          banner "  uo [options] [<command> [suboptions]]\n \n"
          banner 'Options:'
          opt :version, 'Print version and exit'  ## add this here or it goes to bottom of help
          opt :help, 'Show this help message'     ## add this here or it goes to bottom of help
          # opt :no_pager, "Disable paging"
          stop_on COMMAND_MAP.keys
          banner "\nCommands:"
          COMMAND_MAP.each { |cmd, desc| banner format('  %-10s %s', cmd, desc) }
          banner "\nFor help with a specific command: uo <command> --help"
          banner "\nAdditional config options can be set with the 'runner.conf' file inside your project folder"
          banner 'Fewer warnings are presented when using full paths and the user is not inside the project folder'
        end
        return if ARGV.empty?
        @command = ARGV.shift
        begin
          send("opt_#{@command}") ## dispatch to command handling method
        rescue NoMethodError
          abort("Invalid command, please run uo --help for a list of available commands")
        end
      end

      # Define creation commands
      def opt_create
        @subopts = Optimist.options do
          banner "\nURBANopt #{@command}:\n \n"

          opt :project_folder, "\nCreate project directory in your current folder. Name the directory\n" \
          "Add additional tags to specify the method for creating geometry, or use the default urban geometry creation method to create building geometry from geojson coordinates with core and perimeter zoning\n" \
          'Example: uo create --project-folder urbanopt_example_project', type: String, short: :p

          opt :electric, "\nCreate default project with FeatureFile containing electrical network\n" \
          "Example: uo create --project-folder urbanopt_example_project --electric", short: :l

          opt :create_bar, "\nCreate building geometry and add space types using the create bar from building type ratios measure\n" \
          "Refer to https://docs.urbanopt.net/ for more details about the workflow\n" \
          "Used with --project-folder\n" \
          "Example: uo create --project-folder urbanopt_example_project --create-bar\n", short: :c

          opt :floorspace, "\nCreate building geometry and add space types from a floorspace.js file\n" \
          "Refer to https://docs.urbanopt.net/ for more details about the workflow\n" \
          "Used with --project-folder\n" \
          "Example: uo create --project-folder urbanopt_example_project --floorspace\n", short: :f

          opt :combined, "\nCreate project directory that supports running combined residential and commercial workflows\n" \
          "This functionality has not been exhaustively tested and currently supports the Single-Family Detached building type and the Baseline Scenario only\n" \
          "Used with --project-folder\n" \
          "Example: uo create --project-folder urbanopt_example_project --combined\n", short: :d

          opt :empty, "\nUse with --project-folder argument to create an empty project folder\n" \
          "Then add your own Feature file in the project directory you created,\n" \
          "add Weather files in the weather folder and add OpenStudio models of Features\n" \
          "in the Feature File, if any, in the osm_building folder\n" \
          "Example: uo create --empty --project-folder urbanopt_example_project\n", short: :e

          opt :overwrite, "\nUse with --project-folder argument to overwrite existing project folder and replace with new project folder.\n" \
          "May be combined with --empty as well to overwrite existing project folder and replace with new empty project folder.\n" \
          "Example: uo create --overwrite --empty --project-folder urbanopt_project_folder_I_want_destroyed\n", short: :o

          opt :scenario_file, "\nAutomatically create a ScenarioFile containing the features in FeatureFile for each scenario\n" \
          "Provide the FeatureFile used to create the ScenarioFile\n" \
          "Example: uo create --scenario-file example_project.json\n", type: String, short: :s

          opt :single_feature, "\nCreate a ScenarioFile with only a single feature\n" \
          "Use the FeatureID from your FeatureFile\n" \
          "Requires 'scenario-file' also be specified, to say which FeatureFile will create the ScenarioFile\n" \
          "Example: uo create --single-feature 2 --scenario-file example_project.json\n", type: String, short: :i

          opt :reopt_scenario_file, "\nCreate a ScenarioFile that includes a column defining the REopt assumptions file\n" \
          "Specify the existing ScenarioFile that you want to extend with REopt functionality\n" \
          "Example: uo create --reopt-scenario-file baseline_scenario.csv\n", type: String, short: :r
        end
      end

      # Define running commands
      def opt_run
        @subopts = Optimist.options do
          banner "\nURBANopt #{@command}:\n \n"

          opt :reopt, "\nSimulate with additional REopt functionality. Must do this before post-processing with REopt"

          opt :scenario, "\nRun URBANopt simulations for <scenario>\n" \
          "Requires --feature also be specified\n" \
          'Example: uo run --scenario baseline_scenario-2.csv --feature example_project.json', default: 'baseline_scenario.csv', required: true, short: :s

          opt :feature, "\nRun URBANopt simulations according to <featurefile>\n" \
          "Requires --scenario also be specified\n" \
          'Example: uo run --scenario baseline_scenario.csv --feature example_project.json', default: 'example_project.json', required: true, short: :f
        end
      end

      # Define opendss commands
      def opt_opendss
        @subopts = Optimist.options do
          banner "\nURBANopt #{@command}:\n\n"

          opt :scenario, "\nRun OpenDSS simulations for <scenario>\n" \
          "Requires --feature also be specified\n" \
          'Example: uo opendss --scenario baseline_scenario-2.csv --feature example_project.json', default: 'baseline_scenario.csv', short: :s

          opt :feature, "\nRun OpenDSS simulations according to <featurefile>\n" \
          "Requires --scenario also be specified\n" \
          'Example: uo opendss --scenario baseline_scenario.csv --feature example_project.json', default: 'example_project_with_electric_network.json', short: :f

          opt :equipment, "\nRun OpenDSS simulations using <equipmentfile>. If not specified, the electrical_database.json from urbanopt-ditto-reader will be used.\n" \
          'Example: uo opendss --scenario baseline_scenario.csv --feature example_project.json', type: String, short: :e

          opt :timestep, "\nNumber of minutes per timestep in the OpenDSS simulation.\n" \
          "Optional, defaults to analog of simulation timestep set in the FeatureFile\n" \
          "Example: uo opendss --scenario baseline_scenario.csv --feature example_project.json --timestep 15", type: Integer, short: :t

          opt :start_time, "\nBeginning of the period for OpenDSS analysis\n" \
          "Optional, defaults to beginning of simulation time\n" \
          "Example: uo opendss --scenario baseline_scenario.csv --feature example_project.json --start-time '2017/01/15 01:00:00'\n" \
          "Ensure you have quotes around the timestamp, to allow for the space between date & time.", type: String

          opt :end_time, "\nEnd of the period for OpenDSS analysis\n" \
          "Optional, defaults to end of simulation time\n" \
          "Example: uo opendss --scenario baseline_scenario.csv --feature example_project.json --end-time '2017/01/16 01:00:00'\n" \
          "Ensure you have quotes around the timestamp, to allow for the space between date & time.", type: String

          opt :reopt, "\nRun with additional REopt functionality.\n" \
          "Example: uo opendss --scenario baseline_scenario.csv --feature example_project.json --reopt", short: :r

          opt :config, "\nRun OpenDSS using a json config file to specify the above settings.\n" \
          "Example: uo opendss --config path/to/config.json", type: String, short: :c
        end
      end

      # Define post-processing commands
      def opt_process
        @subopts = Optimist.options do
          banner "\nURBANopt #{@command}:\n \n"

          opt :default, "\nStandard post-processing for your scenario"

          opt :opendss, "\nPost-process with OpenDSS"

          opt :reopt_scenario, "\nOptimize for entire scenario with REopt.  Used with the --reopt-scenario-assumptions-file to specify the assumptions to use.\n" \
          'Example: uo process --reopt-scenario'

          opt :reopt_feature, "\nOptimize for each building individually with REopt\n" \
          'Example: uo process --reopt-feature'

          opt :with_database, "\nInclude a sql database output of post-processed results\n" \
          'Example: uo process --default --with-database'

          opt :reopt_scenario_assumptions_file, "\nPath to the scenario REopt assumptions JSON file you want to use. Use with the --reopt-scenario post-processor. " \
          "If not specified, the reopt/base_assumptions.json file will be used", type: String, short: :a

          opt :scenario, "\nSelect which scenario to optimize", default: 'baseline_scenario.csv', required: true, short: :s

          opt :feature, "\nSelect which FeatureFile to use", default: 'example_project.json', required: true, short: :f
        end
      end

      # Define visualization commands
      def opt_visualize
        @subopts = Optimist.options do
          banner "\nURBANopt #{@command}:\n \n"

          opt :feature, "\nVisualize results for all scenarios for a feature file\n" \
            "Provide the FeatureFile to visualize each associated scenario\n" \
            "Example: uo visualize --feature example_project.json\n", type: String, short: :f

          opt :scenario, "\nVisualize results for all features in a scenario\n" \
            "Provide the scenario CSV file to visualize each feature in the scenario\n" \
            "Example: uo visualize --scenario baseline_scenario.csv\n", type: String, short: :s
        end
      end

      # Define validation commands
      def opt_validate
        @subopts = Optimist.options do
          banner "\nURBANopt #{@command}:\n \n"

          opt :eui, "\nCompare eui results in feature reports to limits in validation_schema.yaml\n" \
            "Provide path to the validation_schema.yaml file in your project directory\n" \
            "Example: uo validate --eui validation_schema.yaml", type: String

          opt :scenario, "\nProvide the scenario CSV file to validate features from that scenario\n", type: String, required: true, short: :s

          opt :feature, "\nProvide the Feature JSON file to include info about each feature\n", type: String, required: true, short: :f

          opt :units, "\nSI (kWh/m2/yr) or IP (kBtu/ft2/yr)", type: String, default: 'IP'
        end
      end

      def opt_delete
        @subopts = Optimist.options do
          banner "\nURBANopt #{@command}:\n \n"

          opt :scenario, "\nDelete simulation files for this scenario", default: 'baseline_scenario.csv', required: true
        end
      end

      def opt_des_params
        @subopts = Optimist.options do
          banner "\nURBANopt #{@command}:\n \n"

          opt :sys_param_file, "\nBuild a system parameters JSON config file for Modelica DES simulation using URBANopt SDK outputs\n" \
            "Provide path/name of json file to be created\n" \
            "Example: uo des_params --sys-param-file path/to/sys_params.json", type: String, required: true, short: :y

          opt :scenario, "\nPath to the scenario CSV file\n" \
            "Example: uo des_params --sys-param-file path/to/sys_params.json --scenario path/to/baseline_scenario.csv\n", type: String, required: true, short: :s

          opt :feature, "\nPath to the feature JSON file\n" \
            "Example: uo des_params --sys-param-file path/to/sys_params.json --feature path/to/example_project.json\n", type: String, required: true, short: :f

          opt :model_type, "\nSelection for which kind of DES simulation to perform\n" \
            "Valid choices: 'time_series'", type: String, default: 'time_series'
        end
      end

      def opt_des_create
        @subopts = Optimist.options do
          banner "\nURBANopt #{@command}:\n"
          banner ""
          opt :sys_param, "Path to system parameters config file, possibly created with 'des_params' command in this CLI\n" \
            "Example: uo des_create --sys-param system_parameters.json\n", type: String, required: true, short: :y
          banner ""
          opt :feature, "Path to the feature JSON file\n" \
            "Example: uo des_create --feature path/to/example_project.json", type: String, required: true, short: :f

          opt :des_name, "\nPath to Modelica project dir to be created\n" \
            "Example: uo des_create --des-name path/to/example_modelica_project", type: String, required: true

          opt :model_type, "\nSelection for which kind of DES simulation to perform\n" \
            "Valid choices: 'time_series'", type: String, default: 'time_series'
        end
      end

      def opt_des_run
        @subopts = Optimist.options do
          banner "\nURBANopt #{@command}:\n \n"

          opt :model, "\nPath to Modelica model dir, possibly created with 'des_create' command in this CLI\n" \
            "Example: uo des_run --model path/to/model/dir", type: String, required: true
        end
      end

      attr_reader :mainopts, :command, :subopts
    end

    # Initialize the CLI class
    @opthash = UrbanOptCLI.new

    # Rescue if user only enters 'uo' without a command
    begin
      # Pull out feature and scenario filenames and paths
      if @opthash.subopts[:scenario_file]
        @feature_path, @feature_name = File.split(File.expand_path(@opthash.subopts[:scenario_file]))
      end
    rescue NoMethodError
      abort("Invalid command, please run uo --help for a list of available commands")
    end

    # FIXME: Can this be combined with the above block? This isn't very DRY
    # One solution would be changing scenario_file to feature.
    #   Would that be confusing when creating a ScenarioFile from the FeatureFile?
    if @opthash.subopts[:feature]
      @feature_path, @feature_name = File.split(File.expand_path(@opthash.subopts[:feature]))
    end
    if @opthash.subopts[:scenario]
      @root_dir, @scenario_file_name = File.split(File.expand_path(@opthash.subopts[:scenario]))
      @scenario_name = File.basename(@scenario_file_name, File.extname(@scenario_file_name))
    end

    # Simulate energy usage as defined by ScenarioCSV\
    def self.run_func
      run_dir = File.join(@root_dir, 'run', @scenario_name.downcase)
      csv_file = File.join(@root_dir, @scenario_file_name)
      featurefile = File.join(@root_dir, @feature_name)
      mapper_files_dir = File.join(@root_dir, 'mappers')
      reopt_files_dir = File.join(@root_dir, 'reopt/')
      num_header_rows = 1

      if @feature_id
        feature_run_dir = File.join(run_dir, @feature_id)
        # If run folder for feature exists, remove it
        FileUtils.rm_rf(feature_run_dir) if File.exist?(feature_run_dir)
      end

      feature_file = URBANopt::GeoJSON::GeoFile.from_file(featurefile)
      if @opthash.subopts[:reopt] == true || @opthash.subopts[:reopt_scenario] == true || @opthash.subopts[:reopt_feature] == true
        # TODO: Better way of grabbing assumptions file than the first file in the folder
        reopt_files_dir_contents_list = Dir.children(reopt_files_dir.to_s)
        reopt_assumptions_filename = File.basename(reopt_files_dir_contents_list[0])
        scenario_output = URBANopt::Scenario::REoptScenarioCSV.new(@scenario_name.downcase, @root_dir, run_dir, feature_file, mapper_files_dir, csv_file, num_header_rows, reopt_files_dir, reopt_assumptions_filename)
      else
        scenario_output = URBANopt::Scenario::ScenarioCSV.new(@scenario_name.downcase, @root_dir, run_dir, feature_file, mapper_files_dir, csv_file, num_header_rows)
      end
      scenario_output
    end

    # Create a scenario csv file from a FeatureFile
    # params\
    # +feature_file_path+:: _string_ Path to a FeatureFile
    def self.create_scenario_csv_file(feature_id)
      begin
        feature_file_json = JSON.parse(File.read(File.expand_path(@opthash.subopts[:scenario_file])), symbolize_names: true)
      # Rescue if user provides path to a dir and not a file
      rescue Errno::EISDIR => dir_error
        wrong_path = dir_error.to_s.split(' - ')[-1]
        abort("\nOops! '#{wrong_path}' is a directory. Please provide path to the geojson feature_file")
        # Rescue if file isn't json
      rescue JSON::ParserError => json_error
        abort("\nOops! You didn't provide a json file. Please provide path to the geojson feature_file")
      end
      Dir["#{@feature_path}/mappers/*.rb"].each do |mapper_file|
        mapper_name = File.basename(mapper_file, File.extname(mapper_file))
        scenario_file_name = if feature_id == 'SKIP'
                               "#{mapper_name.downcase}_scenario.csv"
                             else
                               "#{mapper_name.downcase}_scenario-#{feature_id}.csv"
                             end
        CSV.open(File.join(@feature_path, scenario_file_name), 'wb', write_headers: true,
                                                                     headers: ['Feature Id', 'Feature Name', 'Mapper Class']) do |csv|
          begin
              feature_file_json[:features].each do |feature|
              if feature_id == 'SKIP'
                # ensure that feature is a building
                if feature[:properties][:type] == 'Building'
                  csv << [feature[:properties][:id], feature[:properties][:name], "URBANopt::Scenario::#{mapper_name}Mapper"]
                end
              elsif feature_id == feature[:properties][:id]
                csv << [feature[:properties][:id], feature[:properties][:name], "URBANopt::Scenario::#{mapper_name}Mapper"]
              elsif
                # If Feature ID specified does not exist in the Feature File raise error
                unless feature_file_json[:features].any? { |hash| hash[:properties][:id].include?(feature_id.to_s) }
                  abort("\nYou must provide Feature ID from FeatureFile!\n---\n\n")
                end
              end
            end
            # Rescue if json isn't a geojson feature_file
          rescue NoMethodError
            abort("\nOops! You didn't provde a valid feature_file. Please provide path to the geojson feature_file")
          end
        end
      end
    end

    # Write new ScenarioFile with REopt column
    # params \
    # +existing_scenario_file+:: _string_ - Name of existing ScenarioFile
    def self.create_reopt_scenario_file(existing_scenario_file)
      existing_path, existing_name = File.split(File.expand_path(existing_scenario_file))

      # make reopt folder
      Dir.mkdir File.join(existing_path, 'reopt')

      # copy reopt files
      $LOAD_PATH.each do |path_item|
        if path_item.to_s.end_with?('example_files')
          reopt_files = File.join(path_item, 'reopt')
          Pathname.new(reopt_files).children.each { |reopt_file| FileUtils.cp(reopt_file, File.join(existing_path, 'reopt')) }
        end
      end

      table = CSV.read(existing_scenario_file, headers: true, col_sep: ',')
      # Add another column, row by row:
      table.each do |row|
        row['REopt Assumptions'] = 'multiPV_assumptions.json'
      end
      # write new file
      CSV.open(File.join(existing_path, 'REopt_scenario.csv'), 'w') do |f|
        f << table.headers
        table.each { |row| f << row }
      end
    end

    # Create project folder
    # params\
    # +dir_name+:: _string_ Name of new project folder
    #
    # Includes weather for example location, a base workflow file, and mapper files to show a baseline and a high-efficiency option.
    def self.create_project_folder(dir_name, empty_folder = false, overwrite_project = false)
      if overwrite_project == true
        if Dir.exist?(dir_name)
          FileUtils.rm_rf(dir_name)
        end
      elsif overwrite_project == false
        if Dir.exist?(dir_name)
          abort("\nERROR:  there is already a directory here named #{dir_name}... aborting\n---\n\n")
        end
      end

      $LOAD_PATH.each do |path_item|
        if path_item.to_s.end_with?('example_files')

          if empty_folder == false

            Dir.mkdir dir_name
            Dir.mkdir File.join(dir_name, 'weather')
            Dir.mkdir File.join(dir_name, 'mappers')
            Dir.mkdir File.join(dir_name, 'osm_building')
            Dir.mkdir File.join(dir_name, 'visualization')

            # copy config file
            FileUtils.cp(File.join(path_item, 'runner.conf'), dir_name)

            # copy gemfile
            FileUtils.cp(File.join(path_item, 'Gemfile'), dir_name)

            # copy validation schema
            FileUtils.cp(File.join(path_item, 'validation_schema.yaml'), dir_name)

            # copy weather files
            weather_files = File.join(path_item, 'weather')
            Pathname.new(weather_files).children.each { |weather_file| FileUtils.cp(weather_file, File.join(dir_name, 'weather')) }

            # copy visualization files
            viz_files = File.join(path_item, 'visualization')
            Pathname.new(viz_files).children.each { |viz_file| FileUtils.cp(viz_file, File.join(dir_name, 'visualization')) }

            if @opthash.subopts[:electric] == true
              FileUtils.cp(File.join(path_item, 'example_project_with_electric_network.json'), dir_name)
            end

            if @opthash.subopts[:floorspace] == false

              if @opthash.subopts[:electric] != true
                # copy feature file
                FileUtils.cp(File.join(path_item, 'example_project.json'), dir_name)
              end

              # copy osm
              FileUtils.cp(File.join(path_item, 'osm_building/7.osm'), File.join(dir_name, 'osm_building'))
              FileUtils.cp(File.join(path_item, 'osm_building/8.osm'), File.join(dir_name, 'osm_building'))
              FileUtils.cp(File.join(path_item, 'osm_building/9.osm'), File.join(dir_name, 'osm_building'))

              if @opthash.subopts[:create_bar] == false

                # copy the mappers
                FileUtils.cp(File.join(path_item, 'mappers/Baseline.rb'), File.join(dir_name, 'mappers'))
                FileUtils.cp(File.join(path_item, 'mappers/HighEfficiency.rb'), File.join(dir_name, 'mappers'))
                FileUtils.cp(File.join(path_item, 'mappers/ThermalStorage.rb'), File.join(dir_name, 'mappers'))
                FileUtils.cp(File.join(path_item, 'mappers/EvCharging.rb'), File.join(dir_name, 'mappers'))

                # copy osw file
                FileUtils.cp(File.join(path_item, 'mappers/base_workflow.osw'), File.join(dir_name, 'mappers'))

              elsif @opthash.subopts[:create_bar] == true

                # copy the mappers
                FileUtils.cp(File.join(path_item, 'mappers/CreateBar.rb'), File.join(dir_name, 'mappers'))
                FileUtils.cp(File.join(path_item, 'mappers/HighEfficiencyCreateBar.rb'), File.join(dir_name, 'mappers'))

                # copy osw file
                FileUtils.cp(File.join(path_item, 'mappers/createbar_workflow.osw'), File.join(dir_name, 'mappers'))

              end

            elsif @opthash.subopts[:floorspace] == true

              # copy the mappers
              FileUtils.cp(File.join(path_item, 'mappers/Floorspace.rb'), File.join(dir_name, 'mappers'))
              FileUtils.cp(File.join(path_item, 'mappers/HighEfficiencyFloorspace.rb'), File.join(dir_name, 'mappers'))

              # copy osw file
              FileUtils.cp(File.join(path_item, 'mappers/floorspace_workflow.osw'), File.join(dir_name, 'mappers'))

              # copy feature file
              FileUtils.cp(File.join(path_item, 'example_floorspace_project.json'), dir_name)

              # copy osm
              FileUtils.cp(File.join(path_item, 'osm_building/7_floorspace.json'), File.join(dir_name, 'osm_building'))
              FileUtils.cp(File.join(path_item, 'osm_building/7_floorspace.osm'), File.join(dir_name, 'osm_building'))
              FileUtils.cp(File.join(path_item, 'osm_building/8.osm'), File.join(dir_name, 'osm_building'))
              FileUtils.cp(File.join(path_item, 'osm_building/9.osm'), File.join(dir_name, 'osm_building'))
            end

            if @opthash.subopts[:combined]
              # copy residential files
              FileUtils.cp_r(File.join(path_item, 'residential'), File.join(dir_name, 'mappers', 'residential'))
              FileUtils.cp_r(File.join(path_item, 'measures'), File.join(dir_name, 'measures'))
              FileUtils.cp_r(File.join(path_item, 'resources'), File.join(dir_name, 'resources'))
              FileUtils.cp(File.join(path_item, 'example_project_combined.json'), dir_name)
              FileUtils.cp(File.join(path_item, 'base_workflow_res.osw'), File.join(dir_name, 'mappers', 'base_workflow.osw'))
              if File.exist?(File.join(dir_name, 'example_project.json'))
                FileUtils.remove(File.join(dir_name, 'example_project.json'))
              end
            end

          elsif empty_folder == true
            Dir.mkdir dir_name
            FileUtils.cp(File.join(path_item, 'Gemfile'), File.join(dir_name, 'Gemfile'))
            FileUtils.cp_r(File.join(path_item, 'mappers'), File.join(dir_name, 'mappers'))
            FileUtils.cp_r(File.join(path_item, 'visualization'), File.join(dir_name, 'visualization'))

            if @opthash.subopts[:combined]
              # copy residential files
              FileUtils.cp_r(File.join(path_item, 'residential'), File.join(dir_name, 'mappers', 'residential'))
              FileUtils.cp(File.join(path_item, 'base_workflow_res.osw'), File.join(dir_name, 'mappers', 'base_workflow.osw'))
              FileUtils.cp_r(File.join(path_item, 'measures'), File.join(dir_name, 'measures'))
              FileUtils.cp_r(File.join(path_item, 'resources'), File.join(dir_name, 'resources'))
              FileUtils.cp(File.join(path_item, 'example_project_combined.json'), dir_name)
              if File.exist?(File.join(dir_name, 'example_project.json'))
                FileUtils.remove(File.join(dir_name, 'example_project.json'))
              end
            end
          end
        end
      end
    end

    # Check Python
    # params\
    #
    # Check that sys has python 3.7+ installed
    def self.check_python
      results = { python: false, message: '' }
      puts 'Checking system.....'

      # platform agnostic
      stdout, stderr, status = Open3.capture3('python3 -V')
      if stderr && !stderr == ''
        # error
        results[:message] = "ERROR: #{stderr}"
        puts results[:message]
        return results
      end

      # check version
      stdout.slice! 'Python3 '
      if stdout[0].to_i == 2 || (stdout[0].to_i == 3 && stdout[2].to_i < 7)
        # global python version is not 3.7+
        results[:message] = "ERROR: Python version must be at least 3.7.  Found python with version #{stdout}."
        puts results[:message]
        return results
      else
        puts "...Python >= 3.7 found (#{stdout.chomp})"
      end

      # check pip
      stdout, stderr, status = Open3.capture3('pip3 -V')
      if stderr && !stderr == ''
        # error
        results[:message] = "ERROR finding pip: #{stderr}"
        puts results[:message]
        return results
      else
        puts '...pip found'
      end

      # all good
      puts 'System check done.'
      results[:python] = true
      return results
    end

    def self.check_reader
      results = { reader: false, message: '' }

      puts 'Checking for urbanopt-ditto-reader...'

      stdout, stderr, status = Open3.capture3('pip3 list')
      if stderr && !stderr == ''
        # error
        results[:message] = 'ERROR running pip list'
        puts results[:message]
        return results
      end

      res = /^urbanopt-ditto-reader.*$/.match(stdout)
      if res
        # extract version
        version = /\d+.\d+.\d+/.match(res.to_s)
        path = res.to_s.split(' ')[-1]
        puts "...path: #{path}"
        if version
          results[:message] = "Found urbanopt-ditto-reader version #{version}"
          puts "...#{results[:message]}"
          results[:reader] = true
          puts "urbanopt-ditto-reader check done. \n\n"
          return results
        else
          results[:message] = 'urbanopt-ditto-reader version not found.'
          return results
        end
      else
        # no ditto reader
        results[:message] = 'urbanopt-ditto-reader not found.'
        return results
      end
    end

    # Perform CLI actions

    # Create new project folder
    if @opthash.command == 'create' && @opthash.subopts[:project_folder] && @opthash.subopts[:empty] == false
      if @opthash.subopts[:overwrite] == true
        puts "\nOverwriting existing project folder: #{@opthash.subopts[:project_folder]}...\n\n"
        create_project_folder(@opthash.subopts[:project_folder], empty_folder = false, overwrite_project = true)
      elsif @opthash.subopts[:overwrite] == false
        puts "\nCreating a new project folder...\n"
        create_project_folder(@opthash.subopts[:project_folder], empty_folder = false, overwrite_project = false)
        if @opthash.subopts[:floorspace] == false && @opthash.subopts[:create_bar] == true
          puts "\nAn example FeatureFile is included: 'example_project.json'. You may place your own FeatureFile alongside the example."
        elsif @opthash.subopts[:floorspace] == true && @opthash.subopts[:create_bar] == false
          puts "\nAn example FeatureFile is included: 'example_floorspace_project.json'. You may place your own FeatureFile alongside the example."
        end
        puts 'Weather data is provided for the example FeatureFile. Additional weather data files may be downloaded from energyplus.net/weather for free'
        puts "If you use additional weather files, ensure they are added to the 'weather' directory. You will need to configure your mapper file and your osw file to use the desired weather file"
        puts "We recommend using absolute paths for all commands, for cleaner output\n"
      end
    elsif @opthash.command == 'create' && @opthash.subopts[:project_folder] && @opthash.subopts[:empty] == true
      if @opthash.subopts[:overwrite] == true
        puts "\nOverwriting existing project folder: #{@opthash.subopts[:project_folder]} with an empty folder...\n\n"
        create_project_folder(@opthash.subopts[:project_folder], empty_folder = true, overwrite_project = true)
      elsif @opthash.subopts[:overwrite] == false
        puts "\nCreating a new empty project folder...\n"
        create_project_folder(@opthash.subopts[:project_folder], empty_folder = true, overwrite_project = false)
      end
      puts "\nAdd your FeatureFile in the Project directory you just created."
      puts 'Add your weather data files in the Weather folder. They may be downloaded from energyplus.net/weather for free'
      puts 'Add your OpenStudio models for Features in your Feature file, if any in the osm_building folder'
      puts "We recommend using absolute paths for all commands, for cleaner output\n"
    end

    # Create ScenarioFile from FeatureFile
    if @opthash.command == 'create' && @opthash.subopts[:scenario_file]
      if @opthash.subopts[:single_feature]
        puts "\nBuilding sample ScenarioFiles, assigning mapper classes to Feature ID #{@opthash.subopts[:single_feature]}"
        create_scenario_csv_file(@opthash.subopts[:single_feature])
        puts "\nDone\n"
      else
        puts "\nBuilding sample ScenarioFiles, assigning mapper classes to each feature from #{@feature_name}"
        # Skip Feature ID argument if not present
        create_scenario_csv_file('SKIP')
        puts "\nDone\n"
      end
    end

    # Create REopt ScenarioFile from existing
    if @opthash.command == 'create' && @opthash.subopts[:reopt_scenario_file]
      puts "\nCreating ScenarioFile with REopt functionality, extending from #{@opthash.subopts[:reopt_scenario_file]}..."
      create_reopt_scenario_file(@opthash.subopts[:reopt_scenario_file])
      puts "\nDone"
    end

    # Run simulations
    if @opthash.command == 'run' && @opthash.subopts[:scenario] && @opthash.subopts[:feature]
      if @opthash.subopts[:scenario].to_s.include? '-'
        @feature_id = (@feature_name.split(/\W+/)[1]).to_s
      end
      puts "\nSimulating features of '#{@feature_name}' as directed by '#{@scenario_file_name}'...\n\n"
      scenario_runner = URBANopt::Scenario::ScenarioRunnerOSW.new
      scenario_runner.run(run_func)
      puts "\nDone\n"
    end

    if @opthash.command == 'opendss'

      # first check python
      res = check_python
      if res[:python] == false
        puts "\nPython error: #{res[:message]}"
        abort("\nYou must install Python 3.7 or above and pip to use this workflow \n")
      end

      # then check if ditto_reader is installed
      res = check_reader
      if res[:reader] == false
        puts "\nURBANopt ditto reader error: #{res[:message]}"
        abort("\nYou must install urbanopt-ditto-reader to use this workflow: pip install urbanopt-ditto-reader \n")
      end

      # If a config file is supplied, use the data specified there.
      if @opthash.subopts[:config]
        opendss_config = JSON.parse(File.read(File.expand_path(@opthash.subopts[:config])), symbolize_names: true)
        config_scenario_file = opendss_config[:urbanopt_scenario_file]
        config_root_dir = File.dirname(config_scenario_file)
        config_scenario_name = File.basename(config_scenario_file, File.extname(config_scenario_file))
        run_dir = File.join(config_root_dir, 'run', config_scenario_name.downcase)
        featurefile = File.expand_path(opendss_config[:urbanopt_geojson_file])
        # Otherwise use the user-supplied scenario & feature files
      elsif @opthash.subopts[:scenario] && @opthash.subopts[:feature]
        run_dir = File.join(@root_dir, 'run', @scenario_name.downcase)
        featurefile = File.join(@root_dir, @feature_name)
      end

      # Ensure building simulations have been run already
      begin
        feature_list = Pathname.new(File.expand_path(run_dir)).children.select(&:directory?)
        some_random_feature = File.basename(feature_list[0])
        if !File.exist?(File.expand_path(File.join(run_dir, some_random_feature, 'eplusout.sql')))
          abort("ERROR: URBANopt simulations are required before using opendss. Please run and process simulations, then try again.\n")
        end
      rescue Errno::ENOENT # Same abort message if there is no run_dir
        abort("ERROR: URBANopt simulations are required before using opendss. Please run and process simulations, then try again.\n")
      end

      # We're calling the python cli that gets installed when the user installs ditto-reader.
      # If ditto-reader is installed into a venv (recommended), that venv must be activated when this command is called.
      ditto_cli_root = "ditto_reader_cli run-opendss "
      if @opthash.subopts[:config]
        ditto_cli_addition = "--config #{@opthash.subopts[:config]}"
      elsif @opthash.subopts[:scenario] && @opthash.subopts[:feature]
        ditto_cli_addition = "--scenario_file #{@opthash.subopts[:scenario]} --feature_file #{@opthash.subopts[:feature]}"
        if @opthash.subopts[:reopt]
          ditto_cli_addition += " --reopt"
        end
        if @opthash.subopts[:equipment]
          ditto_cli_addition += " --equipment #{@opthash.subopts[:equipment]}"
        end
        if @opthash.subopts[:timestep]
          ditto_cli_addition += " --timestep #{@opthash.subopts[:timestep]}"
        end
        if @opthash.subopts[:start_time]
          ditto_cli_addition += " --start_time '#{@opthash.subopts[:start_time]}'"
        end
        if @opthash.subopts[:end_time]
          ditto_cli_addition += " --end_time '#{@opthash.subopts[:end_time]}'"
        end
      else
        abort("\nCommand must include ScenarioFile & FeatureFile, or a config file that specifies both. Please try again")
      end
      begin
        system(ditto_cli_root + ditto_cli_addition)
      rescue FileNotFoundError
        abort("\nMust post-process results before running opendss. We recommend 'process --default'." \
        "Once opendss is run, you may then 'process --opendss'")
      end
    end

    # Post-process the scenario
    if @opthash.command == 'process'
      if @opthash.subopts[:default] == false && @opthash.subopts[:opendss] == false && @opthash.subopts[:reopt_scenario] == false && @opthash.subopts[:reopt_feature] == false
        abort("\nERROR: No valid process type entered. Must enter a valid process type\n")
      end

      puts 'Post-processing URBANopt results'

      # delete process_status.json
      process_filename = File.join(@root_dir, 'run', @scenario_name.downcase, 'process_status.json')
      FileUtils.rm_rf(process_filename) if File.exist?(process_filename)
      results = []

      default_post_processor = URBANopt::Scenario::ScenarioDefaultPostProcessor.new(run_func)
      scenario_report = default_post_processor.run
      scenario_report.save(file_name = 'default_scenario_report', save_feature_reports = false)
      scenario_report.feature_reports.each(&:save)

      if @opthash.subopts[:with_database] == true
        default_post_processor.create_scenario_db_file
      end

      if @opthash.subopts[:default] == true
        puts "\nDone\n"
        results << { "process_type": 'default', "status": 'Complete', "timestamp": Time.now.strftime('%Y-%m-%dT%k:%M:%S.%L') }
      elsif @opthash.subopts[:opendss] == true
        puts "\nPost-processing OpenDSS results\n"
        opendss_folder = File.join(@root_dir, 'run', @scenario_name, 'opendss')
        if File.directory?(opendss_folder)
          opendss_folder_name = File.basename(opendss_folder)
          opendss_post_processor = URBANopt::Scenario::OpenDSSPostProcessor.new(scenario_report, opendss_results_dir_name = opendss_folder_name)
          opendss_post_processor.run
          puts "\nDone\n"
          results << { "process_type": 'opendss', "status": 'Complete', "timestamp": Time.now.strftime('%Y-%m-%dT%k:%M:%S.%L') }
        else
          results << { "process_type": 'opendss', "status": 'failed', "timestamp": Time.now.strftime('%Y-%m-%dT%k:%M:%S.%L') }
          abort("\nNo OpenDSS results available in folder '#{opendss_folder}'\n")
        end
      elsif (@opthash.subopts[:reopt_scenario] == true) || (@opthash.subopts[:reopt_feature] == true)
        scenario_base = default_post_processor.scenario_base
        # see if reopt-scenario-assumptions-file was passed in, otherwise use the default
        scenario_assumptions = scenario_base.scenario_reopt_assumptions_file
        if (@opthash.subopts[:reopt_scenario] == true && @opthash.subopts[:reopt_scenario_assumptions_file])
          scenario_assumptions = File.expand_path(@opthash.subopts[:reopt_scenario_assumptions_file]).to_s
        end
        puts "\nRunning the REopt Scenario post-processor with scenario assumptions file: #{scenario_assumptions}\n"
        reopt_post_processor = URBANopt::REopt::REoptPostProcessor.new(scenario_report, scenario_assumptions, scenario_base.reopt_feature_assumptions, DEVELOPER_NREL_KEY)
        if @opthash.subopts[:reopt_scenario] == true
          puts "\nPost-processing entire scenario with REopt\n"
          scenario_report_scenario = reopt_post_processor.run_scenario_report(scenario_report: scenario_report, save_name: 'scenario_optimization')
          results << { "process_type": 'reopt_scenario', "status": 'Complete', "timestamp": Time.now.strftime('%Y-%m-%dT%k:%M:%S.%L') }
          puts "\nDone\n"
        elsif @opthash.subopts[:reopt_feature] == true
          puts "\nPost-processing each building individually with REopt\n"
          scenario_report_features = reopt_post_processor.run_scenario_report_features(scenario_report: scenario_report, save_names_feature_reports: ['feature_optimization'] * scenario_report.feature_reports.length, save_name_scenario_report: 'feature_optimization')
          results << { "process_type": 'reopt_feature', "status": 'Complete', "timestamp": Time.now.strftime('%Y-%m-%dT%k:%M:%S.%L') }
          puts "\nDone\n"
        end
      end

      # write process status file
      File.open(process_filename, 'w') { |f| f.write JSON.pretty_generate(results) }

    end

    if @opthash.command == 'visualize'

      if @opthash.subopts[:feature] == false && @opthash.subopts[:scenario] == false
        abort("\nERROR: No valid process type entered. Must enter a valid process type\n")
      end

      if @opthash.subopts[:feature]
        if !@opthash.subopts[:feature].to_s.include? (".json")
          abort("\nERROR: No Feature File specified. Please specify Feature File for creating scenario visualizations.\n")
        end
        run_dir = File.join(@feature_path, 'run')
        scenario_folders = []
        scenario_report_exists = false
        Dir.glob(File.join(run_dir, '/*_scenario')) do |scenario_folder|
          scenario_report = File.join(scenario_folder, 'default_scenario_report.csv')
          if File.exist?(scenario_report)
            scenario_folders << scenario_folder
            scenario_report_exists = true
          else
            puts "\nERROR: Default reports not created for #{scenario_folder}. Please use 'process --default' to create default post processing reports for all scenarios first. Visualization not generated for #{scenario_folder}.\n"
          end
        end
        if scenario_report_exists == true
          puts "\nCreating visualizations for all Scenario results\n"
          URBANopt::Scenario::ResultVisualization.create_visualization(scenario_folders, false)
          vis_file_path = File.join(@feature_path, 'visualization')
          if !File.exist?(vis_file_path)
            Dir.mkdir File.join(@feature_path, 'visualization')
          end
          html_in_path = File.join(vis_file_path, 'input_visualization_scenario.html')
          if !File.exist?(html_in_path)
            $LOAD_PATH.each do |path_item|
              if path_item.to_s.end_with?('example_files')
                FileUtils.cp(File.join(path_item, 'visualization', 'input_visualization_scenario.html'), html_in_path)
              end
            end
          end
          html_out_path = File.join(@feature_path, 'run', 'scenario_comparison.html')
          FileUtils.cp(html_in_path, html_out_path)
          puts "\nDone\n"
        end
      end

      if @opthash.subopts[:scenario]
        if !@opthash.subopts[:scenario].to_s.include? (".csv")
          abort("\nERROR: No Scenario File specified. Please specify Scenario File for feature visualizations.\n")
        end
        run_dir = File.join(@root_dir, 'run', @scenario_name.downcase)
        feature_report_exists = false
        csv = CSV.read(File.expand_path(@opthash.subopts[:scenario]), headers: true)
        feature_names = csv['Feature Name']
        feature_folders = []
        # loop through building feature ids from scenario csv
        csv['Feature Id'].each do |feature|
          feature_report = File.join(run_dir, feature, 'feature_reports')
          if File.exist?(feature_report)
            feature_report_exists = true
            feature_folders << File.join(run_dir, feature)
          else
            puts "\nERROR: Default reports not created for #{feature}. Please use 'process --default' to create default post processing reports for all features first. Visualization not generated for #{feature}.\n"
          end
        end
        if feature_report_exists == true
          puts "\nCreating visualizations for Feature results in the Scenario\n"
          URBANopt::Scenario::ResultVisualization.create_visualization(feature_folders, true, feature_names)
          vis_file_path = File.join(@root_dir, 'visualization')
          if !File.exist?(vis_file_path)
            Dir.mkdir File.join(@root_dir, 'visualization')
          end
          html_in_path = File.join(vis_file_path, 'input_visualization_feature.html')
          if !File.exist?(html_in_path)
            $LOAD_PATH.each do |path_item|
              if path_item.to_s.end_with?('example_files')
                FileUtils.cp(File.join(path_item, 'visualization', 'input_visualization_feature.html'), html_in_path)
              end
            end
          end
          html_out_path = File.join(@root_dir, 'run', @scenario_name, 'feature_comparison.html')
          FileUtils.cp(html_in_path, html_out_path)
          puts "\nDone\n"
        end
      end

    end

    # Compare EUI in default_feature_reports.json with a user-editable set of bounds
    if @opthash.command == 'validate'
      puts "\nValidating:"
      if !@opthash.subopts[:eui] && !@opthash.subopts[:foobar]
        abort("\nERROR: No type of validation specified. Please enter a sub-command when using validate.\n")
      end
      # Validate EUI
      if @opthash.subopts[:eui]
        puts "Energy Use Intensity"
        original_feature_file = JSON.parse(File.read(File.expand_path(@opthash.subopts[:feature])), symbolize_names: true)
        # Build list of paths to each feature in the given Scenario
        feature_ids = CSV.read(@opthash.subopts[:scenario], headers: true)
        feature_list = []
        feature_ids['Feature Id'].each do |feature|
          if Dir.exist?(File.join(@root_dir, 'run', @scenario_name, feature))
            feature_list << File.join(@root_dir, 'run', @scenario_name, feature)
          else
            puts "Warning: did not find a directory for FeatureID: #{feature} ...skipping"
          end
        end
        validation_file_name = File.basename(@opthash.subopts[:eui])
        validation_params = YAML.load_file(File.expand_path(@opthash.subopts[:eui]))
        unit_value = validation_params['EUI'][@opthash.subopts[:units]]['Units']
        # Validate EUI for only the features used in the scenario
        original_feature_file[:features].each do |feature| # Loop through each feature in the scenario
          next if !feature_ids['Feature Id'].include? feature[:properties][:id] # Skip features not in the scenario
          feature_list.each do |feature_path| # Match ids in FeatureFile
            next if feature_path.split('/')[-1] != feature[:properties][:id] # Skip until feature ids match
            feature_dir_list = Pathname.new(feature_path).children.select(&:directory?) # Folders in the feature directory
            feature_dir_list.each do |feature_dir|
              next if !File.basename(feature_dir).include? "default_feature_reports" # Get the folder which can have a variable name
              @json_feature_report = JSON.parse(File.read(File.join(feature_dir, 'default_feature_reports.json')), symbolize_names: true)
            end
            if !@json_feature_report[:reporting_periods][0][:site_EUI_kbtu_per_ft2]
              abort("ERROR: No EUI present. Perhaps you didn't simulate an entire year?")
            end
            if @opthash.subopts[:units] == 'IP'
              feature_eui_value = @json_feature_report[:reporting_periods][0][:site_EUI_kbtu_per_ft2]
            elsif @opthash.subopts[:units] == 'SI'
              feature_eui_value = @json_feature_report[:reporting_periods][0][:site_EUI_kwh_per_m2]
            else
              abort("\nERROR: Units type not recognized. Please use a valid option in the CLI")
            end
            building_type = feature[:properties][:building_type] # From FeatureFile
            if feature_eui_value > validation_params['EUI'][@opthash.subopts[:units]][building_type]['max']
              puts "\nFeature #{File.basename(feature_path)} EUI of #{feature_eui_value.round(2)} #{unit_value} is greater than the validation maximum."
            elsif feature_eui_value < validation_params['EUI'][@opthash.subopts[:units]][building_type]['min']
              puts "\nFeature #{File.basename(feature_path)} EUI of #{feature_eui_value.round(2)} #{unit_value} is less than the validation minimum."
            else
              puts "\nFeature #{File.basename(feature_path)} EUI of #{feature_eui_value.round(2)} #{unit_value} is within bounds set by #{validation_file_name}."
            end
          end
        end
      end
    end

    if @opthash.command == 'des_params'
      # We're calling the python cli that gets installed when the user pip installs geojson-modelica-reader.
      # If geojson-modelica-reader is installed into a venv (recommended), that venv must be activated when this command is called.
      des_cli_root = "uo_des build-sys-param"
      if @opthash.subopts[:sys_param_file]
        des_cli_addition = " #{@opthash.subopts[:sys_param_file]}"
        if @opthash.subopts[:scenario]
          des_cli_addition += " #{@opthash.subopts[:scenario]}"
        end
        if @opthash.subopts[:feature]
          des_cli_addition += " #{@opthash.subopts[:feature]}"
        end
        if @opthash.subopts[:model_type]
          des_cli_addition += " #{@opthash.subopts[:model_type]}"
        end
      else
        abort("\nCommand must include new system parameter file name, ScenarioFile, & FeatureFile. Please try again")
      end
      begin
        system(des_cli_root + des_cli_addition)
      rescue FileNotFoundError
        abort("\nMust simulate using 'uo run' before preparing Modelica models.")
      end
    end

    if @opthash.command == 'des_create'
      # We're calling the python cli that gets installed when the user pip installs geojson-modelica-reader.
      # If geojson-modelica-reader is installed into a venv (recommended), that venv must be activated when this command is called.
      des_cli_root = "uo_des create-model"
      if @opthash.subopts[:sys_param]
        des_cli_addition = " #{@opthash.subopts[:sys_param]}"
        if @opthash.subopts[:feature]
          des_cli_addition += " #{@opthash.subopts[:feature]}"
        end
        if @opthash.subopts[:des_name]
          des_cli_addition += " #{File.expand_path(@opthash.subopts[:des_name])}"
        end
        if @opthash.subopts[:model_type]
          des_cli_addition += " #{@opthash.subopts[:model_type]}"
        end
      else
        abort("\nCommand must include system parameter file name, FeatureFile, and model name. Please try again")
      end
      begin
        system(des_cli_root + des_cli_addition)
      rescue FileNotFoundError
        abort("\nMust simulate using 'uo run' before preparing Modelica models.")
      end
    end

    if @opthash.command == 'des_run'
      # We're calling the python cli that gets installed when the user pip installs geojson-modelica-reader.
      # If geojson-modelica-reader is installed into a venv (recommended), that venv must be activated when this command is called.
      des_cli_root = "uo_des run-model"
      if @opthash.subopts[:model]
        des_cli_addition = " #{File.expand_path(@opthash.subopts[:model])}"
      else
        abort("\nCommand must include Modelica model name. Please try again")
      end
      begin
        system(des_cli_root + des_cli_addition)
      rescue FileNotFoundError
        abort("\nMust simulate using 'uo run' before preparing Modelica models.")
      end
    end

    # Delete simulations from a scenario
    if @opthash.command == 'delete'
      scenario_results_dir = File.join(@root_dir, 'run', @scenario_name.downcase)
      puts "\nDeleting previous results from '#{@scenario_name}'...\n"
      FileUtils.rm_rf(scenario_results_dir)
      puts "\nDone\n"
    end
  end
end
