require_relative 'config/environment'
require 'erb'
require 'rack/utils'
require 'resend'

Resend.api_key = ENV.fetch('RESEND_TOKEN')

class Mailer
  VIEWS = File.join(ROOT, 'views', 'mailers')

  # Renders a mailer template outside of any Sinatra request context.
  # `template` is the file name without the trailing ".erb", e.g. "welcome.html".
  class RenderContext
    def initialize(locals)
      locals.each { |name, value| define_singleton_method(name) { value } }
    end

    def h(text)
      Rack::Utils.escape_html(text.to_s)
    end

    def get_binding
      binding
    end
  end

  def self.render(template, locals)
    path = File.join(VIEWS, "#{template}.erb")
    ERB.new(File.read(path), trim_mode: '-').result(RenderContext.new(locals).get_binding)
  end

  def self.welcome(user)
    locals = { user: user, app_url: "https://#{ENV.fetch('APP_URL')}" }

    params = {
      from: "No-Reply <no-reply@tramsapp.com>",
      to: [user.email],
      subject: "Välkommen till Trams!",
      html: render('welcome.html', locals),
      text: render('welcome.text', locals)
    }

    sent = Resend::Emails.send(params)
  end

  def self.password_reset(user, token)
    locals = { user: user, reset_url: "https://#{ENV.fetch('APP_URL')}/auth/reset_password?token=#{token}"}

    params = {
      from: "No-Reply <no-reply@tramsapp.com>",
      to: [user.email],
      subject: "Glömt ditt lösenord? Byt det här",
      html: render('password_reset.html', locals),
      text: render('password_reset.text', locals)
    }

    sent = Resend::Emails.send(params)
  end

  def self.verify_email(user, token)
    locals = { user: user, verify_url: "https://#{ENV.fetch('APP_URL')}/auth/verify_email?token=#{token}" }

    params = {
      from: "No-Reply <no-reply@tramsapp.com>",
      to: [user.email],
      subject: "Bekräfta din e-postadress",
      html: render('verify_email.html', locals),
      text: render('verify_email.text', locals)
    }

    sent = Resend::Emails.send(params)
  end
end
