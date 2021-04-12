# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require 'openstudio'
if File.exist? File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/resources/hpxml-measures/HPXMLtoOpenStudio/resources')) # Hack to run ResStock on AWS
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/resources/hpxml-measures/HPXMLtoOpenStudio/resources'))
elsif File.exist? File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/hpxml-measures/HPXMLtoOpenStudio/resources')) # Hack to run ResStock unit tests locally
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/hpxml-measures/HPXMLtoOpenStudio/resources'))
elsif File.exist? File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources')
else
  resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
end
require File.join(resources_path, 'meta_measure')

# start the measure
class BuildResidentialModel < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Build Residential Model'
  end

  # human readable description
  def description
    return 'Builds the OpenStudio Model for an existing residential building.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Builds the residential OpenStudio Model using the geojson feature file, which contains the specified parameters for each existing building.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    arg = OpenStudio::Ruleset::OSArgument.makeIntegerArgument('feature_id', true)
    arg.setDisplayName('Feature ID')
    arg.setDescription('The feature ID passed from Baseline.rb.')
    args << arg

    measures_dir = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources/hpxml-measures'))
    measure_subdir = 'BuildResidentialHPXML'
    full_measure_path = File.join(measures_dir, measure_subdir, 'measure.rb')
    measure = get_measure_instance(full_measure_path)

    measure.arguments(model).each do |arg|
      next if ['hpxml_path'].include? arg.name
      args << arg
    end

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    args = get_argument_values(runner, arguments(model), user_arguments)

    # optionals: get or remove
    args.keys.each do |arg|
      begin # TODO: how to check if arg is an optional or not?
        if args[arg].is_initialized
          args[arg] = args[arg].get
        else
          args.delete(arg)
        end
      rescue
      end
    end

    # get file/dir paths
    resources_dir = File.absolute_path(File.join(File.dirname(__FILE__), '../../resources'))
    meta_measure_file = File.join(resources_dir, 'meta_measure.rb')
    require File.join(File.dirname(meta_measure_file), File.basename(meta_measure_file, File.extname(meta_measure_file)))
    workflow_json = File.join(resources_dir, 'measure-info.json')

    # apply HPXML measures
    measures_dir = File.join(resources_dir, 'hpxml-measures')
    check_dir_exists(measures_dir, runner)

    # these will get added back in by unit_model
    model.getBuilding.remove
    model.getShadowCalculation.remove
    model.getSimulationControl.remove
    model.getSite.remove
    model.getTimestep.remove

    units = get_unit_positions(runner, args)
    if units.empty?
      return false
    end

    units.each_with_index do |unit, unit_num|
      unit_model = OpenStudio::Model::Model.new

      hpxml_path = File.expand_path("../#{unit['name']}.xml")

      # BuildResidentialHPXML
      measure_subdir = 'BuildResidentialHPXML'
      full_measure_path = File.join(measures_dir, measure_subdir, 'measure.rb')
      check_file_exists(full_measure_path, runner)

      # fill the measure args hash with default values
      measure_args = args.clone
      measure_args.delete('feature_id')

      measures = {}
      measures[measure_subdir] = []
      measure_args['hpxml_path'] = hpxml_path
      begin
        measure_args['software_program_used'] = File.basename(File.absolute_path(File.join(File.dirname(__FILE__), '../../..')))
      rescue
      end
      begin
        version_rb File.absolute_path(File.join(File.dirname(__FILE__), '../../../lib/uo_cli/version.rb'))
        require version_rb
        measure_args['software_program_version'] = URBANopt::CLI::VERSION
      rescue
      end
      measure_args['schedules_random_seed'] = args['feature_id'] * (unit_num + 1) # variation across units, but deterministic
      if unit.keys.include?('geometry_level')
        measure_args['geometry_level'] = unit['geometry_level']
      end
      if unit.keys.include?('geometry_horizontal_location')
        measure_args['geometry_horizontal_location'] = unit['geometry_horizontal_location']
      end
      if unit.keys.include?('geometry_orientation')
        measure_args['geometry_orientation'] = unit['geometry_orientation']
      end
      measures[measure_subdir] << measure_args

      # HPXMLtoOpenStudio
      measure_subdir = 'HPXMLtoOpenStudio'
      full_measure_path = File.join(measures_dir, measure_subdir, 'measure.rb')
      check_file_exists(full_measure_path, runner)

      # fill the measure args hash with default values
      measure_args = {}

      measures[measure_subdir] = []
      measure_args['hpxml_path'] = hpxml_path
      measure_args['output_dir'] = File.expand_path('..')
      measure_args['debug'] = true
      measures[measure_subdir] << measure_args

      if not apply_child_measures(measures_dir, measures, runner, unit_model, workflow_json, "#{unit['name']}.osw", true)
        return false
      end

      # store metadata for default feature reports measure
      standards_number_of_above_ground_stories = Integer(args['geometry_num_floors_above_grade'])
      standards_number_of_stories = Integer(args['geometry_num_floors_above_grade'])
      number_of_conditioned_stories = Integer(args['geometry_num_floors_above_grade'])
      if ['UnconditionedBasement', 'ConditionedBasement'].include?(args['geometry_foundation_type'])
        standards_number_of_stories += 1
        if ['ConditionedBasement'].include?(args['geometry_foundation_type'])
          number_of_conditioned_stories += 1
        end
      end

      standards_number_of_living_units = 1
      if args.keys.include?('geometry_building_num_units')
        standards_number_of_living_units = Integer(args['geometry_building_num_units'])
      end

      case args['geometry_unit_type']
      when 'single-family detached'
        building_type = 'Single-Family Detached'
      when 'single-family attached'
        building_type = 'Single-Family Attached'
      when 'apartment unit'
        building_type = 'Multifamily'
      end

      unit_model.getSpaceTypes.each do |space_type|
        next unless space_type.standardsSpaceType.is_initialized
        next if space_type.standardsSpaceType.get != 'living space'
        space_type.setStandardsBuildingType(building_type)
      end

      unit_model.getBuilding.setStandardsBuildingType('Residential')
      unit_model.getBuilding.setStandardsNumberOfAboveGroundStories(standards_number_of_above_ground_stories)
      unit_model.getBuilding.setStandardsNumberOfStories(standards_number_of_stories)
      unit_model.getBuilding.setNominalFloortoFloorHeight(Float(args['geometry_wall_height']))
      unit_model.getBuilding.setStandardsNumberOfLivingUnits(standards_number_of_living_units)
      unit_model.getBuilding.additionalProperties.setFeature('NumberOfConditionedStories', number_of_conditioned_stories)

      if unit_num == 0 # for the first building unit, add everything

        model.addObjects(unit_model.objects, true)

      else # for single-family attached and multifamily, add "almost" everything

        # shift the unit so it's not right on top of the previous one
        unit_model.getSpaces.sort.each do |space|
          space.setYOrigin(100.0 * unit_num) # meters
        end

        # prefix all objects with name using unit number. May be cleaner if source models are setup with unique names
        sensors_and_actuators_map = {}
        unit_model.getEnergyManagementSystemSensors.each do |sensor|
          sensors_and_actuators_map[sensor.name.to_s] = "#{unit['name'].gsub(' ', '_')}_#{sensor.name}"
          sensor.setKeyName("#{unit['name']} #{sensor.keyName}") unless sensor.keyName.empty?
        end
        unit_model.getEnergyManagementSystemActuators.each do |actuator|
          sensors_and_actuators_map[actuator.name.to_s] = "#{unit['name'].gsub(' ', '_')}_#{actuator.name}"
        end

        # variables in program lines don't get updated automatically
        unit_model.getEnergyManagementSystemPrograms.each do |program|
          new_lines = []
          program.lines.each_with_index do |line, i|
            sensors_and_actuators_map.each do |old_name, new_name|
              line = line.gsub(" #{old_name}", " #{new_name}") if line.include?(" #{old_name}")
              line = line.gsub("(#{old_name} ", "(#{new_name} ") if line.include?("(#{old_name} ")
              line = line.gsub(" #{old_name})", " #{new_name})") if line.include?(" #{old_name})")
              line = line.gsub("-#{old_name})", "-#{new_name})") if line.include?("-#{old_name})")
              line = line.gsub("+#{old_name})", "+#{new_name})") if line.include?("+#{old_name})")
              line = line.gsub("*#{old_name})", "*#{new_name})") if line.include?("*#{old_name})")
            end
            new_lines << line
          end
          program.setLines(new_lines)
        end

        unit_model.objects.each do |model_object|
          next if model_object.name.nil?

          model_object.setName("#{unit['name']} #{model_object.name.to_s}")
        end

        # we already have the following unique objects from the first building unit
        unit_model.getConvergenceLimits.remove
        unit_model.getOutputDiagnostics.remove
        unit_model.getRunPeriodControlDaylightSavingTime.remove
        unit_model.getShadowCalculation.remove
        unit_model.getSimulationControl.remove
        unit_model.getSiteGroundTemperatureDeep.remove
        unit_model.getSiteGroundTemperatureShallow.remove
        unit_model.getSite.remove
        unit_model.getInsideSurfaceConvectionAlgorithm.remove
        unit_model.getOutsideSurfaceConvectionAlgorithm.remove
        unit_model.getTimestep.remove
        unit_model.getFoundationKivaSettings.remove
        unit_model_objects = []
        unit_model.objects.each do |obj|
          unit_model_objects << obj unless obj.to_Building.is_initialized # if we remove this, we lose all thermal zones
        end

        model.addObjects(unit_model_objects, true)
      end
    end

    # save the "re-composed" model with all building units to file
    building_path = File.expand_path(File.join('..', 'whole_building.osm'))
    model.save(building_path, true)

    return true
  end

  def get_unit_positions(runner, args)
    units = []
    if args['geometry_unit_type'] == 'single-family detached'
      units << {'name' => "unit 1"}
    elsif args['geometry_unit_type'] == 'single-family attached'
      (1..args['geometry_building_num_units']).to_a.each do |unit_num|
        if unit_num == 1
          units << {'name' => "unit #{unit_num}", 'geometry_horizontal_location' => 'Left'}
        elsif unit_num == args['geometry_building_num_units']
          units << {'name' => "unit #{unit_num}", 'geometry_horizontal_location' => 'Right'}
        else
          units << {'name' => "unit #{unit_num}", 'geometry_horizontal_location' => 'Middle'}
        end
      end
    elsif args['geometry_unit_type'] == 'apartment unit'
      if args['geometry_corridor_position'] == 'Double Exterior'

        num_units_per_floor = (Float(args['geometry_building_num_units']) / Float(args['geometry_num_floors_above_grade'])).ceil
        if num_units_per_floor == 1
          runner.registerError("num_units_per_floor='#{num_units_per_floor}' not supported.")
          return units
        end

        floor = 1
        position = 1
        (1..args['geometry_building_num_units']).to_a.each do |unit_num|

          geometry_orientation = 180.0
          if position.even?
            geometry_orientation = 0.0
          end

          geometry_horizontal_location = 'Middle'
          if position == 1
            geometry_horizontal_location = 'Left'
          elsif position == 2
            geometry_horizontal_location = 'Right'
          elsif position == num_units_per_floor and num_units_per_floor.even?
            geometry_horizontal_location = 'Left'
          elsif position == num_units_per_floor and num_units_per_floor.odd?
            geometry_horizontal_location = 'Right'
          elsif position + 1 == num_units_per_floor and num_units_per_floor.even?
            geometry_horizontal_location = 'Right'
          elsif position + 1 == num_units_per_floor and num_units_per_floor.odd?
            geometry_horizontal_location = 'Left'
          end

          if floor == 1
            geometry_level = 'Bottom'
          elsif floor == args['geometry_num_floors_above_grade']
            geometry_level = 'Top'
          else
            geometry_level = 'Middle'
          end

          if unit_num % num_units_per_floor == 0
            floor += 1
            position = 0
          end
          position += 1

          units << {'name' => "unit #{unit_num}", 'geometry_horizontal_location' => geometry_horizontal_location, 'geometry_level' => geometry_level, 'geometry_orientation' => geometry_orientation}
        end
      else
        runner.registerError("geometry_corridor_position='#{args['geometry_corridor_position']}' not supported.")
        return units
      end
    end
    return units
  end

  def get_measure_args_default_values(model, args, measure)
    measure.arguments(model).each do |arg|
      next unless arg.hasDefaultValue

      case arg.type.valueName.downcase
      when "boolean"
        args[arg.name] = arg.defaultValueAsBool
      when "double"
        args[arg.name] = arg.defaultValueAsDouble
      when "integer"
        args[arg.name] = arg.defaultValueAsInteger
      when "string"
        args[arg.name] = arg.defaultValueAsString
      when "choice"
        args[arg.name] = arg.defaultValueAsString
      end
    end
  end
end

# register the measure to be used by the application
BuildResidentialModel.new.registerWithApplication
