# details.rb
# Copyright IBM & Istio Authors
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
##############################################################################
# Very rough implementation of a REST API for demo purposes of Instana tracing
# Additions very welcome

require 'sinatra'
# remove the comment to enable instana tracing and monitoring
require 'instana'

# needed for the docker image to bind to any IP address not onyl 127.0.0.1
set :bind, '0.0.0.0'
set :port, 9080

get '/' do
  'Awesome!'
end

get '/details/0' do
  get_book_details(0).to_json
end

get '/health' do
  'I´m healthy!'
end

def get_book_details(id)
    if ENV['ENABLE_EXTERNAL_BOOK_SERVICE'] === 'true' then
      # the ISBN of one of Comedy of Errors on the Amazon
      # that has Shakespeare as the single author
        isbn = '0486424618'
        return fetch_details_from_external_service(isbn, id)
    end

    return {
        'id' => id,
        'author': 'William Shakespeare',
        'year': 1595,
        'type' => 'paperback',
        'pages' => 200,
        'publisher' => 'PublisherA',
        'language' => 'English',
        'ISBN-10' => '1234567890',
        'ISBN-13' => '123-1234567890'
    }
end
