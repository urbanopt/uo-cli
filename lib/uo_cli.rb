#!/usr/bin/ ruby

#*********************************************************************************
# URBANopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC, and other
# contributors. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
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
#*********************************************************************************

require "uo_cli/version"
require "optparse"
require "urbanopt/geojson"
require "urbanopt/scenario"
require "csv"
require "json"


module URBANopt
  module CLI

    # Set up user interface
    @user_input = {}
    OptionParser.new do |opts|
        opts.banner = "Usage: uo [-pmradsfv]\n" +
        "\n" +
        "URBANopt CLI. \n" +
        "First create a project folder with -p, then run additional commands as desired \n"
        opts.separator ""

        opts.on("-p", "--project_folder <DIR>",String, "Create project directory named <DIR> in your current folder") do |folder|
            @user_input[:project_folder] = folder
        end
        opts.on("-m", "--make_scenario", String, "Create ScenarioCSV files for each MapperFile using the Feature file path. Must specify -f argument") do
            @user_input[:make_scenario_from] = "Create scenario files from FeatureFiles according to the MapperFiles in the 'mappers' directory"  # This text does not get displayed to the user
        end
        opts.on("-r", "--run", String, "Run simulations. Must specify -s & -f arguments") do
            @user_input[:run_scenario] = "Run simulations"  # This text does not get displayed to the user
        end
        opts.on("-a", "--aggregate", String, "Aggregate individual feature results to scenario-level results. Must specify -s & -f arguments") do
            @user_input[:aggregate] = "Aggregate all features to a whole Scenario"  # This text does not get displayed to the user
        end
        opts.on("-d", "--delete_scenario <SFP>", String, "Delete results from scenario specified by <SFP> (ScenarioCSV file path). Must specify -s argument") do
            @user_input[:delete_scenario] = "Delete scenario results that were created from <SFP>"  # This text does not get displayed to the user
        end
        opts.on("-s", "--scenario_file <SFP>", String, "Specify <SFP> (ScenarioCSV file path). Used as input for other commands") do |scenario|
            @user_input[:scenario] = scenario
        end
        opts.on("-f", "--feature_file <FFP>", String, "Specify <FFP> (Feature file path). Used as input for other commands") do |feature|
            @user_input[:feature] = feature
        end
        opts.on("-v", "--version", "Show CLI version and exit") do
            @user_input[:version_request] = URBANopt::CLI::VERSION
        end
    end.parse!
    # TODO: In newer versions of Ruby we can eliminate the need for each "do" block above by using this syntax. Have to see how run & agg work in that case
    # end.parse!(into: @user_input)


    # Simulate energy usage for each Feature in the Scenario\
    # params\
    # +scenario+:: _string_ Path to csv file that defines the scenario\
    # +feature_file_path+:: _string_ Path to Feature File used to describe set of features in the district
    # 
    # FIXME: This only works when scenario_file and feature_file are in the project root directory
    # Also, feels a little weird that now I'm only using instance variables and not passing anything to this function. I guess it's ok?
    def self.run_func
        name = "#{@scenario_name.split('.')[0].capitalize}"
        root_dir = File.absolute_path(@scenario_root)
        run_dir = File.join(root_dir, 'run', name.downcase)
        csv_file = File.join(root_dir, @scenario_name)
        featurefile = File.join(root_dir, @feature_name)
        mapper_files_dir = File.join(root_dir, "mappers")
        num_header_rows = 1

        feature_file = URBANopt::GeoJSON::GeoFile.from_file(featurefile)
        scenario_output = URBANopt::Scenario::ScenarioCSV.new(name, root_dir, run_dir, feature_file, mapper_files_dir, csv_file, num_header_rows)
        return scenario_output
    end

    the_parser = OptionParser.new do |opts|
        opts.banner = "Usage: uo [-pmradsf]\n" +
        "\n" +
        "URBANopt CLI. \n" +
        "For new projects, first create a project folder with -p, then run additional commands as desired \n" +
        "For existing projects, specify your feature and scenarioCSV files to run (-r) and aggregate (-a) results"
        
        opts.separator ""

        opts.on("-p", "--project_folder <DIR>", "Create project directory named <DIR> in your current folder", String) do |folder|
            @user_input[:project_folder] = folder
        end
        opts.on("-m", "--make_scenario <FFP>", "Create baseline ScenarioCSV file from <FFP> (Feature file path)", String) do |feature|
            @user_input[:make_scenario_from] = feature
        end
        opts.on("-r", "--run", "Run simulations. Must specify -s & -f arguments", String) do |run|
            @user_input[:run_scenario] = "Run simulations"
        end
        opts.on("-a", "--aggregate","Aggregate individual feature results to scenario-level results. Must specify -s & -f arguments", String) do |agg|
            @user_input[:aggregate] = "Aggregate all features to a whole Scenario"
        end
        opts.on("-d", "--delete_scenario <SFP>", "Delete results from scenario specified by <SFP> (ScenarioCSV file path)", String) do |delete|
            @user_input[:delete_scenario] = delete
        end
        opts.on("-s", "--scenario_file <SFP>", "Specify <SFP> (ScenarioCSV file path). Used when running and aggregating simulations", String) do |scenario|
            @user_input[:scenario] = scenario
        end
        opts.on("-f", "--feature_file <FFP>", "Specify <FFP> (Feature file path). Used when running and aggregating simulations", String) do |feature|
            @user_input[:feature] = feature
        end
    end

    begin
        the_parser.parse!
    rescue OptionParser::InvalidOption => e
      puts e
    end

    # TODO: In newer versions of Ruby we can eliminate the need for each "do" block above by using this syntax. Have to see how run & agg work in that case
    # end.parse!(into: @user_input)


    # Simulate energy usage for each Feature in the Scenario\
    # params\
    # +scenario+:: _string_ Path to csv file that defines the scenario\
    # +feature_file_path+:: _string_ Path to Feature File used to describe set of features in the district
    # 
    # FIXME: This only works when scenario_file and feature_file are in the project root directory
    # Also, feels a little weird that now I'm only using instance variables and not passing anything to this function. I guess it's ok?
    def self.run_func
        name = "#{@scenario_name.split('.')[0].capitalize}"
        root_dir = File.absolute_path(@scenario_root)
        run_dir = File.join(root_dir, 'run', name.downcase)
        csv_file = File.join(root_dir, @scenario_name)
        featurefile = File.join(root_dir, @feature_name)
        mapper_files_dir = File.join(root_dir, "mappers")
        num_header_rows = 1

        feature_file = URBANopt::GeoJSON::GeoFile.from_file(featurefile)
        scenario_output = URBANopt::Scenario::ScenarioCSV.new(name, root_dir, run_dir, feature_file, mapper_files_dir, csv_file, num_header_rows)
        return scenario_output
    end

    # Create a scenario csv file from a FeatureFile
    # params\
    # +feature_file_path+:: _string_ Path to a FeatureFile
    def self.create_scenario_csv_file(feature_file_path)
        feature_file_json = JSON.parse(File.read(feature_file_path), :symbolize_names => true)
        Dir["#{@feature_root}/mappers/*.rb"].each do |mapper_file|
            mapper_root, mapper_base = File.split(mapper_file)
            mapper_name = mapper_base.split('.')[0]
            scenario_file_name = "#{mapper_name.downcase}_scenario.csv"
            CSV.open(File.join(@feature_root, scenario_file_name), "wb", :write_headers => true,
            :headers => ["Feature Id","Feature Name","Mapper Class"]) do |csv|
                feature_file_json[:features].each do |feature|
                    csv << [feature[:properties][:id], feature[:properties][:name], "URBANopt::Scenario::#{mapper_name}Mapper"]
                end
            end
        end
    end


    # Create project folder
    # params\
    # +dir_name+:: _string_ Name of new project folder
    # 
    # Folder gets created in the current working directory
    # Includes weather for UO's example location, a base workflow file, and mapper files to show a baseline and a high-efficiency option.
    def self.create_project_folder(dir_name)
        if Dir.exist?(dir_name)
             puts "ERROR:  there is already a directory here named #{dir_name}... aborting"
        else
            puts "CREATING URBANopt project directory: #{dir_name}"
            Dir.mkdir dir_name
            Dir.mkdir File.join(dir_name, 'mappers')
            Dir.mkdir File.join(dir_name, 'weather')
            mappers_dir_abs_path = File.absolute_path(File.join(dir_name, 'mappers/'))
            weather_dir_abs_path = File.absolute_path(File.join(dir_name, 'weather/'))

            # FIXME: When https://github.com/urbanopt/urbanopt-example-geojson-project/pull/24 gets merged these files will change
            example_feature_file = "https://raw.githubusercontent.com/urbanopt/urbanopt-example-geojson-project/develop/example_project.json"
            example_gem_file = "https://raw.githubusercontent.com/urbanopt/urbanopt-example-geojson-project/develop/Gemfile"
            remote_mapper_files = ["https://raw.githubusercontent.com/urbanopt/urbanopt-example-geojson-project/develop/mappers/base_workflow.osw",
                                   "https://raw.githubusercontent.com/urbanopt/urbanopt-example-geojson-project/develop/mappers/Baseline.rb",
                                   "https://raw.githubusercontent.com/urbanopt/urbanopt-example-geojson-project/develop/mappers/HighEfficiency.rb"]
            remote_weather_files = ["https://raw.githubusercontent.com/urbanopt/urbanopt-example-geojson-project/develop/weather/USA_NY_Buffalo-Greater.Buffalo.Intl.AP.725280_TMY3.epw",
                                    "https://raw.githubusercontent.com/urbanopt/urbanopt-example-geojson-project/develop/weather/USA_NY_Buffalo-Greater.Buffalo.Intl.AP.725280_TMY3.ddy",
                                    "https://raw.githubusercontent.com/urbanopt/urbanopt-example-geojson-project/develop/weather/USA_NY_Buffalo-Greater.Buffalo.Intl.AP.725280_TMY3.stat"]
            
            # Download files to user's local machine
            remote_mapper_files.each do |mapper_file|
                mapper_root, mapper_base = File.split(mapper_file)
                mapper_download = open(mapper_file)
                IO.copy_stream(mapper_download, File.join(mappers_dir_abs_path, mapper_base))
            end
            remote_weather_files.each do |weather_file|
                weather_root, weather_base = File.split(weather_file)
                weather_download = open(weather_file)
                IO.copy_stream(weather_download, File.join(weather_dir_abs_path, weather_base))
            end
            gem_root, gem_base = File.split(example_gem_file)
            example_gem_download = open(example_gem_file)
            IO.copy_stream(example_gem_download, File.join(dir_name, gem_base))

            feature_root, feature_base = File.split(example_feature_file)
            example_feature_download = open(example_feature_file)
            IO.copy_stream(example_feature_download, File.join(dir_name, feature_base))
        end
    end


    # Perform CLI actions
    if @user_input[:project_folder]
        create_project_folder(@user_input[:project_folder])
        puts "\nAn example FeatureFile is included: 'example_project.json'. You may place your own FeatureFile alongside the example."
        puts "Weather data is provided for the example FeatureFile. Additional weather data files may be downloaded from energyplus.net/weather for free"
        puts "If you use additional weather files, ensure they are added to the 'weather' directory. You will need to configure your mapper file or your osw file to use the desired weather file"
        puts "Next, move inside your new folder and create a baseline ScenarioFile using this CLI: 'uo -m -f <FFP>'"
    end

    if @user_input[:make_scenario_from]
        if @user_input[:feature].nil?
            abort("\nYou must provide a valid path to a FeatureFile!\n---\n\n")
        end
        @feature_root, @feature_name = File.split(@user_input[:feature])
        puts "\nBuilding sample efficiency ScenarioFiles from #{@feature_name}..."
        create_scenario_csv_file(@user_input[:feature])
        puts "Done"
    end

    if @user_input[:run_scenario]
        if @user_input[:scenario].nil?
            abort("\nYou must provide a valid path to a ScenarioFile!\n---\n\n")
        end
        if @user_input[:feature].nil?
            abort("\nYou must provide a valid path to a FeatureFile!\n---\n\n")
        end
        @scenario_root, @scenario_name = File.split(@user_input[:scenario])
        @feature_root, @feature_name = File.split(@user_input[:feature])
        puts "\nSimulating features of '#{@feature_name}' according to '#{@scenario_name}'..."
        scenario_runner = URBANopt::Scenario::ScenarioRunnerOSW.new
        scenario_runner.run(run_func())
        puts "Done"
    end

    if @user_input[:aggregate]
        if @user_input[:scenario].nil?
            abort("\nYou must provide a valid path to a ScenarioFile!\n---\n\n")
        end
        if @user_input[:feature].nil?
            abort("\nYou must provide a valid path to a FeatureFile!\n---\n\n")
        end
        @scenario_root, @scenario_name = File.split(@user_input[:scenario])
        @feature_root, @feature_name = File.split(@user_input[:feature])
        puts "\nAggregating results across all features of #{@feature_name} according to '#{@scenario_name}'..."
        scenario_result = URBANopt::Scenario::ScenarioDefaultPostProcessor.new(run_func()).run
        scenario_result.save
        puts "Done"
    end

    if @user_input[:delete_scenario]
        if @user_input[:scenario].nil?
            abort("\nYou must provide a valid path to a ScenarioFile!\n---\n\n")
        end
        @scenario_root, @scenario_name = File.split(@user_input[:scenario])
        scenario_name = @scenario_name.split('.')[0]
        scenario_results_dir = File.join(@scenario_root, 'run', scenario_name)
        puts "\nDeleting previous results from '#{@scenario_name}'..."
        FileUtils.rm_rf(scenario_results_dir)
        puts "Done"
    end

    if @user_input[:version_request]
        puts "URBANopt CLI version: #{@user_input[:version_request]}"
    end

  end  # End CLI

end  # End Urbanopt
