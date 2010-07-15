#
# Author:: John Alberts (<john.m.alberts@gmail.com>)
# Copyright:: Copyright (c) 2010 John Alberts
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/knife'
require 'highline'
require 'chef/search/query'
require 'socket'
require 'timeout'

class Chef
  class Knife
    class NodeReport < Knife
      def highline
        @h ||= HighLine.new
      end

      def is_port_open?(ip, port)
        begin
          Timeout::timeout(1) do
            begin
              s = TCPSocket.new(ip, port)
              s.close
              return true
            rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
              return false
            end
          end
        rescue Timeout::Error
        end

        return false
      end

      def showreport(node)
        if node["ohai_time"]
          current_time = Date.today
          date = Date.parse(Time.at(node["ohai_time"]).to_s)
          hours, minutes, seconds, frac = Date.day_fraction_to_time(current_time - date)
          hours_text   = "#{hours} hour#{hours == 1 ? ' ' : 's'}"
          minutes_text = "#{minutes} minute#{minutes == 1 ? ' ' : 's'}"
          last_check_in = hours < 1 ? "#{minutes_text}" : "#{hours_text}"
          roles = node.run_list.roles.reject{|n| n =~ /lucid|cluster|ec2|gluster/}.join(",")
          status = is_port_open?("#{node.ec2.public_ipv4}","22") ? "UP" : "DOWN"
          puts "#{roles.ljust(50)}#{node.ec2.instance_id.ljust(20)}#{node.ec2.public_hostname.ljust(50)}#{status.ljust(20)}#{last_check_in.ljust(20)}"
        end
      end

      def run
        tasklist = []
        puts "#{'Roles'.ljust(50)}#{'instance_id'.ljust(20)}#{'public_hostname'.ljust(50)}#{'SSH Status'.ljust(20)}#{'last check in time'.ljust(20)}"
        Chef::Search::Query.new.search(:node, '*:*') do |node|
          task = Thread.new { showreport(node) }
          tasklist << task
        end
        tasklist.each { |task|
          task.join
        }
      end
    end
  end
end

