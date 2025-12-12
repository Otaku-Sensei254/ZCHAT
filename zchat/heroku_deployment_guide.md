# Heroku Deployment Guide for ZChat

This guide provides the steps to deploy the ZChat application to Heroku.

## 1. Create a Heroku App

First, create a new Heroku app and set the buildpack to the Elixir buildpack.

```bash
heroku create your-app-name --buildpack hashnuke/elixir
```

Replace `your-app-name` with the desired name for your application.

## 2. Add the Phoenix Static Buildpack

Next, add the Phoenix static buildpack to your Heroku app. This buildpack is responsible for building the static assets (CSS and JavaScript).

```bash
heroku buildpacks:add --index 1 https://github.com/gjaldon/heroku-buildpack-phoenix-static.git
```

## 3. Set Environment Variables

The application requires several environment variables to be set on Heroku.

### 3.1. Generate a Secret Key

Generate a new secret key for your application.

```bash
mix phx.gen.secret
```

### 3.2. Set the Secret Key

Set the `SECRET_KEY_BASE` environment variable on Heroku using the key you just generated.

```bash
heroku config:set SECRET_KEY_BASE="your-generated-secret-key"
```

Replace `your-generated-secret-key` with the key you generated in the previous step.

### 3.3. Set the Phoenix Host

Set the `PHX_HOST` environment variable to your Heroku app's domain.

```bash
heroku config:set PHX_HOST="your-app-name.herokuapp.com"
```

Replace `your-app-name` with the name of your Heroku app.

### 3.4. Set Cloudinary Variables

The application uses Cloudinary for file uploads. Set the following environment variables with your Cloudinary credentials.

```bash
heroku config:set CLOUDINARY_API_KEY="your-api-key"
heroku config:set CLOUDINARY_SECRET="your-api-secret"
heroku config:set CLOUDINARY_CLOUD_NAME="your-cloud-name"
heroku config:set CLOUDINARY_PRESET="your-preset"
```

## 4. Provision a Database

Provision a Heroku Postgres database for your application.

```bash
heroku addons:create heroku-postgresql:hobby-dev
```

This will create a new database and set the `DATABASE_URL` environment variable automatically.

## 5. Deploy to Heroku

Finally, deploy your application to Heroku.

```bash
git push heroku main
```

Your application should now be deployed and running on Heroku. You can open it in your browser with the following command:

```bash
heroku open
```
