require 'rack'
require 'json'

PAGES = {
  "/" => "Hi, welcome to the home page!",
  "/about" => "About us: we are http hackers.",
  "/news" => "We haven't made much news yet with this server, but stay tuned.",
  "/details" => "Dummy",
  "/details/0" => "Dummy"
}
PAGE_NOT_FOUND = "Sorry, there's nothing here."

class App
  def call(env)
    response_headers = {}
    response_body = []

    ### cookies

    request_cookies = Rack::Utils.parse_cookies(env)

    # set the session identifier if one doesn't already exist

    unless request_cookies["session_key"]
      Rack::Utils.set_cookie_header!(response_headers, "session_key", Time.now.to_f)
    end

    # count the number of page visits

    # nil.to_i returns 0, so if this cookie isn't set, the count will be 0:
    count = request_cookies["session_count"].to_i
    count += 1
    Rack::Utils.set_cookie_header!(response_headers, "session_count", count)

    ### routing

    path = env["PATH_INFO"]
    if PAGES.keys.include? path
      status = 200
      if path === "/details/0" then
        response_body.push get_book_details(0).to_json
      else
        response_body.push PAGES[path]

      end
    else
      status = 404
      response_body.push PAGE_NOT_FOUND
    end


    ### add our tracker count to the response body on a new line:

    response_body.push " You've visited #{count} times!"

    ### return the response object

    [status, response_headers, response_body]
  end
end

def get_book_details(id)
    if ENV['ENABLE_EXTERNAL_BOOK_SERVICE'] === 'true' then
      # the ISBN of one of Comedy of Errors on the Amazon
      # that has Shakespeare as the single author
        isbn = '0486424618'
        return fetch_details_from_external_service(isbn, id, headers)
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

Rack::Handler::WEBrick.run App.new
