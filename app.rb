require 'shopify_api'
require 'sinatra'
require 'httparty'
require 'dotenv'
require 'openssl'
require 'base64'
require 'pry'
Dotenv.load

API_KEY = ENV['API_KEY']
API_SECRET = ENV['API_SECRET']
APP_URL = 'https://dfcca1a4.ngrok.io'

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
    shop = shop_strings(@@tokens)
    access_token = access_token_string(@@tokens)
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
    shop = shop_strings(@@tokens)
    access_token = access_token_string(@@tokens)
    create_session(shop, access_token)
    webhook = {
      topic: params['topic'],
      address: params['address'],
      format: params['format']
    }
    ShopifyAPI::Webhook.create(webhook)
  end

  post '/webhooks/product_update' do
    hmac = request.env['HTTP_X_SHOPIFY_HMAC_SHA256']

    request.body.rewind
    data = request.body.read

    webhook = verify_webhook(hmac,data)
    if webhook
      puts "200 - webhook successfull"
       shop = request.env['HTTP_X_SHOPIFY_SHOP_DOMAIN']
       token = @@tokens[shop]
       create_session(shop, token)

      json_data = JSON.parse(data)
       id = json_data['id']
       product = ShopifyAPI::Product.find(id)
       product.title = "Webhook troll"
       product.save
    else
      puts  "Webhook could not be created."
    end
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
      create_webhook
      redirect "https://#{params['shop']}/admin/apps"
    else
      puts "There was a problem in the authorization process. Please try again."
    end
  end

  def create_session(shop, token)
    session = ShopifyAPI::Session.new(shop, token)
    ShopifyAPI::Base.activate_session(session)
  end

  def shop_strings(tokens)
    shop = tokens.map { |k,v| "#{k}" }.join("")
  end

  def access_token_string(tokens)
    access_token = tokens.map { |k,v| "#{v}" }.join("")
  end

  def create_webhook
    webhook = {
      topic: 'products/update',
      address:"#{APP_URL}/webhooks/product_update",
      format: 'json'
    }
    ShopifyAPI::Webhook.create(webhook)
  end
  def verify_webhook(hmac, data)
    digest = OpenSSL::Digest.new('sha256')
    calculated_hmac = Base64.encode64(OpenSSL::HMAC.digest(digest, API_SECRET, data)).strip

    hmac == calculated_hmac
  end
end
NatesProducts.run!
