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

require 'urbanopt/reporting'
require 'openstudio/common_measures'
require 'openstudio/model_articulation'

require_relative 'HighEfficiency'

require 'json'

module URBANopt
  module Scenario
    class EvChargingMapper < HighEfficiencyMapper
      def create_osw(scenario, features, feature_names)
        osw = super(scenario, features, feature_names)

        feature = features[0]

        def ev_charging_type(building_type)
          typical_home = ['Single-Family', 'Multifamily (2 to 4 units)', 'Multifamily (5 or more units)', 'Lodging']
          typical_public = ['Public assembly', 'Strip shopping mall', 'Enclosed mall', 'Retail other than mall', 'Food service', 'Nonrefrigerated warehouse', 'Food sales', 'Refrigerated warehouse', 'Religious worship', 'Service', 'Public order and safety', 'Uncovered Parking', 'Covered Parking']
          typical_work = ['Office', 'Laboratory', 'Education', 'Inpatient health care', 'Outpatient health care', 'Nursing']

          if typical_home.include? building_type
            return 'Typical Home'
          elsif typical_public.include? building_type
            return 'Typical Public'
          elsif typical_work.include? building_type
            return 'Typical Work'
          end
        end

        # add EV loads
        ev_charging = nil

        begin
          ev_charging = feature.ev_charging
        rescue
        end

        if ev_charging != true
          puts "Please set ev_charging to true to add EV loads."
        elsif ev_charging == true
          OpenStudio::Extension.set_measure_argument(osw, 'add_ev_load', '__SKIP__', false)
          begin
            ev_charging_station_type = feature.ev_charging_station_type
          rescue
          end
          if !ev_charging_station_type.nil? && !ev_charging_station_type.empty?
            OpenStudio::Extension.set_measure_argument(osw, 'add_ev_load', 'chg_station_type', ev_charging_station_type)
          else
            building_type = feature.building_type
            # For mixed use building ev_charging_station_type must be specified
            if building_type == 'Mixed use'
              puts "Specify the ev_charging_station_type for the Feature, add_ev_load measure not applied."
            else
              ev_charging_station_type = ev_charging_type(building_type)
              OpenStudio::Extension.set_measure_argument(osw, 'add_ev_load', 'chg_station_type', ev_charging_station_type)
            end
          end

          begin
            if ev_charging_station_type == 'Typical Work'
              delay_type = feature.delay_type
              OpenStudio::Extension.set_measure_argument(osw, 'add_ev_load', 'delay_type', delay_type)
            end
          rescue
          end

          begin
            ev_charging_behavior = feature.ev_charging_behavior
            if !ev_charging_behavior.nil? && !ev_charging_behavior.empty?
               OpenStudio::Extension.set_measure_argument(osw, 'add_ev_load', 'charge_behavior', ev_charging_behavior)
            end
          rescue
          end

          begin
            ev_percent = feature.ev_percent
            if !ev_percent.nil? && !ev_percent.empty?
              OpenStudio::Extension.set_measure_argument(osw, 'add_ev_load', 'ev_percent', ev_percent)
            end
          rescue
          end

          #Add EMS Control to EV charging only if ev_charging is true
          begin
            ev_curtailment_frac = feature.ev_curtailment_frac
          rescue
          end

          if !ev_curtailment_frac.nil?
            OpenStudio::Extension.set_measure_argument(osw, 'add_ems_to_control_ev_charging', '__SKIP__', false)
            OpenStudio::Extension.set_measure_argument(osw, 'add_ems_to_control_ev_charging', 'curtailment_frac', ev_curtailment_frac)
          end

        end

        return osw
      end
    end
  end
end
