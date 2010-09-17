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
    class Report < Knife
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
          cluster_name = node.cluster.name
          roles = node.run_list.reject{|n| n == "role[#{cluster_name}]" }.join(",")
          status = is_port_open?("#{node.ec2.public_ipv4}","22") ? "UP" : "DOWN"

          puts "#{cluster_name.ljust(20)}#{roles.ljust(50)}#{node.ec2.instance_id.ljust(20)}#{node.ec2.public_ipv4.ljust(20)}#{status.ljust(20)}#{last_check_in.ljust(20)}"
        end
      end

      def run
        tasklist = []
        puts "#{'Cluster'.ljust(20)}#{'Roles'.ljust(50)}#{'instance_id'.ljust(20)}#{'public_ipv4'.ljust(20)}#{'SSH Status'.ljust(20)}#{'last check in time'.ljust(20)}"
        nodes = Chef::Search::Query.new.search(:node, '*:*').first
        sorted = nodes.reject{|n| n.nil? }.sort {|a,b| a.cluster.name <=> b.cluster.name }
        sorted.each do |node|
          showreport(node)
        end
      end
    end
  end
end

