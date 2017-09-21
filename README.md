# Oauth Products

Shopify app that uses the `shopify_api` gem and Oauth to test some Product endpoints. Also uses `ngrok` to tunnel to localhost.

To use:

1. `Bundle install` after cloning the repository.
2. Create an app in your partner dashboard.
3. Create a `.env` file to store environment variables (API_KEY, API_SECRET).
4. Change the `APP_URL` as necessary.

> If you change the `APP_URL` in the `app.rb` file, ensure that you are also
changing it in your partners dashboard.
