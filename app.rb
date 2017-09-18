require 'shopify_api'
require 'sinatra'
require 'httparty'
require 'dotenv'
require 'openssl'
require 'pry'
Dotenv.load

API_KEY = ENV['API_KEY']
API_SECRET = ENV['API_SECRET']
APP_URL = 'https://91f323ae.ngrok.io'

class NatesProducts < Sinatra::Base
    attr_reader :tokens

  def initialize
    @@tokens = {}
    super
  end

  get '/' do
    headers({'X-Frame-Options' => ''})
    erb :index
  end

  post '/products' do
    shop = @@tokens.map { |k,v| "#{k}" }.join("")
    access_token = @@tokens.map { |k,v| "#{v}" }.join("")
    create_session(shop, access_token)
    product = {
      title: params['title'],
      product_type: params['product_type'],
      vendor: params['vendor'],
      variants:[{
        price: params['price']
        }]
    }
    ShopifyAPI::Product.create(product)
    redirect "/"
  end

  post '/webhooks' do
    shop = @@tokens.map { |k,v| "#{k}" }.join("")
    access_token = @@tokens.map { |k,v| "#{v}" }.join("")
    create_session(shop, access_token)
    webhook = {
      topic: params['topic'],
      address: params['address'],
      format: params['format']
    }
    ShopifyAPI::Webhook.create(webhook)
    redirect "/"
  end

  get '/natesproducts/install' do

      shop = params['shop']
      scope = 'write_orders, write_products'
      install_url = "https://#{shop}/admin/oauth/authorize?client_id=#{API_KEY}&scope=#{scope}&redirect_uri=#{APP_URL}/natesproducts/auth"
      if @@tokens[shop]
        redirect "/"
      else
        redirect install_url
      end
  end

  get '/natesproducts/auth' do
    hmac = params['hmac']

    h = {
      shop: params['shop'],
      code: params['code'],
      timestamp: params['timestamp']
    }

    h = h.map{|k,v| "#{k}=#{v}"}.sort.join("&")
    digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), API_SECRET, h)

    url = "https://#{params['shop']}/admin/oauth/access_token"
    payload = {
    client_id: API_KEY,
    client_secret: API_SECRET,
    code: params['code']
    }

    response = HTTParty.post(url, body: payload)

    if digest == hmac
      response = JSON.parse(response.body)
      @@tokens[params['shop']] = response['access_token']
      create_session(params['shop'], response['access_token'])
      product = {
        title: "Oauth works",
        product_type: "sinatra",
        vendor: "oauth"
      }
      ShopifyAPI::Product.create(product)

      redirect "https://#{params['shop']}/admin/apps"
    else
      status [403, "NOPE"]
    end
  end

  def create_session(shop, token)
    session = ShopifyAPI::Session.new(shop, token)
    ShopifyAPI::Base.activate_session(session)
  end

end
NatesProducts.run!
