require 'rack'
require 'json'
#require 'instana'

PAGES = {
  "/" => "Hi, welcome to the home page!",
  "/about" => "About us: we are http hackers.",
  "/health" => "Details is healthy",
  "/details" => "Dummy",
  "/details/0" => "Dummy"
}
PAGE_NOT_FOUND = "Sorry, there's nothing here."

class App
  def call(env)
    response_headers = {}
    response_body = []

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

    ### return the response object

    [status, response_headers, response_body]
  end
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

def fetch_details_from_external_service(isbn, id)
    uri = URI.parse('https://www.googleapis.com/books/v1/volumes?q=isbn:' + isbn)
    http = Net::HTTP.new(uri.host, ENV['DO_NOT_ENCRYPT'] === 'true' ? 80:443)
    http.read_timeout = 5 # seconds

    # DO_NOT_ENCRYPT is used to configure the details service to use either
    # HTTP (true) or HTTPS (false, default) when calling the external service to
    # retrieve the book information.
    #
    # Unless this environment variable is set to true, the app will use TLS (HTTPS)
    # to access external services.
    unless ENV['DO_NOT_ENCRYPT'] === 'true' then
      http.use_ssl = true
    end

    request = Net::HTTP::Get.new(uri.request_uri)
    # headers.each { |header, value| request[header] = value }

    response = http.request(request)

    json = JSON.parse(response.body)
    book = json['items'][0]['volumeInfo']

    language = book['language'] === 'en'? 'English' : 'unknown'
    type = book['printType'] === 'BOOK'? 'paperback' : 'unknown'
    isbn10 = get_isbn(book, 'ISBN_10')
    isbn13 = get_isbn(book, 'ISBN_13')

    return {
        'id' => id,
        'author': book['authors'][0],
        'year': book['publishedDate'],
        'type' => type,
        'pages' => book['pageCount'],
        'publisher' => book['publisher'],
        'language' => language,
        'ISBN-10' => isbn10,
        'ISBN-13' => isbn13
  }

end

Rack::Handler::WEBrick.run(App.new, :BindAddress => '*', :Port => 9080)
