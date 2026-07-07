require_relative 'test_helper'
require_relative '../mailer'

class MailerTest < Minitest::Test
  def setup
    @user = User.new(name: 'Anna', email: 'anna@example.com')
  end

  def test_render_welcome_html_includes_the_users_name
    html = Mailer.render('welcome.html', user: @user, app_url: 'https://tramsapp.com')
    assert_includes html, 'Anna'
    assert_includes html, 'https://tramsapp.com'
  end

  def test_render_escapes_html_in_the_users_name
    @user.name = '<script>evil</script>'
    html = Mailer.render('welcome.html', user: @user, app_url: 'https://tramsapp.com')
    refute_includes html, '<script>'
    assert_includes html, '&lt;script&gt;'
  end

  def test_render_text_version_has_no_html_tags
    text = Mailer.render('welcome.text', user: @user, app_url: 'https://tramsapp.com')
    refute_match(/<[^>]+>/, text)
  end

  def test_welcome_sends_via_resend_with_expected_params
    sent_params = nil
    Resend::Emails.stub(:send, ->(params) { sent_params = params }) do
      Mailer.welcome(@user)
    end

    assert_equal ['anna@example.com'], sent_params[:to]
    assert_equal 'Välkommen till Trams!', sent_params[:subject]
    assert_includes sent_params[:html], 'Anna'
    assert sent_params[:text]
  end

  def test_render_password_reset_html_includes_the_reset_link
    html = Mailer.render('password_reset.html', user: @user, reset_url: 'https://tramsapp.com/auth/reset_password?token=abc123')
    assert_includes html, 'abc123'
    assert_includes html, 'Anna'
  end

  def test_render_password_reset_text_has_no_html_tags
    text = Mailer.render('password_reset.text', user: @user, reset_url: 'https://tramsapp.com/auth/reset_password?token=abc123')
    refute_match(/<[^>]+>/, text)
  end

  def test_password_reset_sends_via_resend_with_expected_params
    sent_params = nil
    Resend::Emails.stub(:send, ->(params) { sent_params = params }) do
      Mailer.password_reset(@user, 'abc123')
    end

    assert_equal ['anna@example.com'], sent_params[:to]
    assert_includes sent_params[:html], 'abc123'
    assert_includes sent_params[:text], 'abc123'
  end

  def test_render_verify_email_html_includes_the_verify_link
    html = Mailer.render('verify_email.html', user: @user, verify_url: 'https://tramsapp.com/auth/verify_email?token=abc123')
    assert_includes html, 'abc123'
    assert_includes html, 'Anna'
  end

  def test_render_verify_email_text_has_no_html_tags
    text = Mailer.render('verify_email.text', user: @user, verify_url: 'https://tramsapp.com/auth/verify_email?token=abc123')
    refute_match(/<[^>]+>/, text)
  end

  def test_verify_email_sends_via_resend_with_expected_params
    sent_params = nil
    Resend::Emails.stub(:send, ->(params) { sent_params = params }) do
      Mailer.verify_email(@user, 'abc123')
    end

    assert_equal ['anna@example.com'], sent_params[:to]
    assert_includes sent_params[:html], 'abc123'
    assert_includes sent_params[:text], 'abc123'
  end
end
