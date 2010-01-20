# Copyright 2008 J. Chris Anderson
# 
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
# 
#        http://www.apache.org/licenses/LICENSE-2.0
# 
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require "rubygems"
gem 'json'
require 'json'
gem 'rest-client'
require 'rest_client'

require 'uri'

$:.unshift File.dirname(__FILE__) unless
  $:.include?(File.dirname(__FILE__)) ||
  $:.include?(File.expand_path(File.dirname(__FILE__)))
  
$COUCHREST_DEBUG ||= false
  
require 'couchrest/monkeypatches'

# = CouchDB, close to the metal
module CouchRest
  VERSION    = '1.09' unless self.const_defined?("VERSION")
  
  autoload :Server,       'couchrest/core/server'
  autoload :Database,     'couchrest/core/database'
  autoload :Parent,       'couchrest/core/parent'
  autoload :Response,     'couchrest/core/response'
  autoload :Array,        'couchrest/core/array'
  autoload :Hash,         'couchrest/core/hash'
  autoload :Document,     'couchrest/core/document'
  autoload :Design,       'couchrest/core/design'
  autoload :View,         'couchrest/core/view'
  autoload :Model,        'couchrest/core/model'
  autoload :Pager,        'couchrest/helper/pager'
  autoload :FileManager,  'couchrest/helper/file_manager'
  autoload :Streamer,     'couchrest/helper/streamer'
  autoload :Upgrade,      'couchrest/helper/upgrade'
  
  autoload :ExtendedDocument,     'couchrest/more/extended_document'
  autoload :CastedModel,          'couchrest/more/casted_model'
  
  require File.join(File.dirname(__FILE__), 'couchrest', 'mixins')

  # The CouchRest module methods handle the basic JSON serialization 
  # and deserialization, as well as query parameters. The module also includes
  # some helpers for tasks like instantiating a new Database or Server instance.
  class << self

    # extracted from Extlib
    #
    # Constantize tries to find a declared constant with the name specified
    # in the string. It raises a NameError when the name is not in CamelCase
    # or is not initialized.
    #
    # @example
    # "Module".constantize #=> Module
    # "Class".constantize #=> Class
    def constantize(camel_cased_word)
      unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ camel_cased_word
        raise NameError, "#{camel_cased_word.inspect} is not a valid constant name!"
      end
      Object.module_eval("::#{$1}", __FILE__, __LINE__)
    end
    
    # extracted from Extlib
    #    
    # Capitalizes the first word and turns underscores into spaces and strips _id.
    # Like titleize, this is meant for creating pretty output.
    #
    # @example
    #   "employee_salary" #=> "Employee salary"
    #   "author_id" #=> "Author"
    def humanize(lower_case_and_underscored_word)
      lower_case_and_underscored_word.to_s.gsub(/_id$/, "").gsub(/_/, " ").capitalize
    end
    
    # todo, make this parse the url and instantiate a Server or Database instance
    # depending on the specificity.
    def new(*opts)
      Server.new(*opts)
    end
    
    # set proxy for RestClient to use
    def proxy url
      RestClient.proxy = url
    end

    def url(url)
      parsed = URI.parse url
      def parsed.couch_split
        @couch_split ||= path.sub(/^\//,'').split('/',2)
      end
      def parsed.database
        couch_split.first
      end
      def parsed.doc
        (couch_split.length == 2 && couch_split.last) || ''
      end
      parsed
    end
     

    # ensure that a database exists
    # creates it if it isn't already there
    # returns it after it's been created
    def database! url
      cr = CouchRest.new(url)
      cr.database!(cr.url.database)
    end
  
    def database url
      cr = CouchRest.new(url)
      cr.database(cr.url.database)
    end

    def http_headers
      {"Content-Type" => 'application/json; charset=UTF-8'}
    end
    
    def put(uri, doc = nil)
      payload = doc.to_json if doc
      begin
        JSON.parse(RestClient.put(uri, payload,  CouchRest.http_headers))
      rescue Exception => e
        if $COUCHREST_DEBUG == true
          raise "Error while sending a PUT request #{uri}\npayload: #{payload.inspect}\n#{e}"
        else
          raise e
        end
      end
    end

    def get(uri)
      begin
        JSON.parse(RestClient.get(uri), :max_nesting => false)
      rescue => e
        if $COUCHREST_DEBUG == true
          raise "Error while sending a GET request #{uri}\n: #{e}"
        else
          raise e
        end
      end
    end
  
    def post uri, doc = nil
      payload = doc.to_json if doc
      begin
        JSON.parse(RestClient.post(uri, payload, CouchRest.http_headers))
      rescue Exception => e
        if $COUCHREST_DEBUG == true
          raise "Error while sending a POST request #{uri}\npayload: #{payload.inspect}\n#{e}"
        else
          raise e
        end
      end
    end
  
    def delete uri
      JSON.parse(RestClient.delete(uri))
    end
    
    def copy uri, destination
      JSON.parse(RestClient.copy(uri, {'Destination' => destination}))
    end
  
    def paramify_url url, params = {}
      if params && !params.empty?
        query = params.collect do |k,v|
          v = v.to_json if %w{key startkey endkey}.include?(k.to_s)
          "#{k}=#{CGI.escape(v.to_s)}"
        end.join("&")
        url = "#{url}?#{query}"
      end
      url
    end
  end # class << self
end
