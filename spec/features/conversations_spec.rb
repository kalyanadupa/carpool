# frozen_string_literal: true
require 'spec_helper'

describe 'Conversations' do
  let(:driver) { create :user }
  let(:passenger) { create :user, uid: '123456' }
  let(:itinerary) { create :itinerary, user: driver }

  it 'allows to see own notifications' do
    receiver = create :user, uid: '123456'
    sender = create :user, name: 'Message Sender'
    itinerary = create :itinerary, user: receiver
    conversation = create :conversation, users: [receiver, sender], conversable: itinerary
    conversation.messages << build(:message, sender: sender, body: "<script>alert('toasty!);</script>")

    visit user_facebook_omniauth_authorize_path
    visit conversations_path

    expect(page).to have_content 'Message Sender'
    expect(page).to have_css "a[href=\"#{conversation_path(conversation)}\"]"
  end

  it 'allows to send messages' do
    message = 'can I come with you?'
    another_message = 'please please please!'

    visit user_facebook_omniauth_authorize_path
    visit new_conversation_path(itinerary_id: itinerary.id)

    fill_in 'conversation_message_body', with: message
    click_button I18n.t('conversations.form.send')
    expect(page).to have_content message
    fill_in 'conversation_message_body', with: another_message
    click_button I18n.t('conversations.form.send')
    expect(page).to have_content message
    expect(page).to have_content another_message
  end

  it 'rescues from creation errors' do
    visit user_facebook_omniauth_authorize_path
    visit new_conversation_path(itinerary_id: itinerary.id)

    click_button I18n.t('conversations.form.send')

    expect(page).to have_css '.alert-danger'
  end

  it 'rescues from update errors' do
    receiver = create :user, uid: '123456'
    sender = create :user
    itinerary = create :itinerary, user: receiver
    conversation = create :conversation, users: [receiver, sender], conversable: itinerary
    conversation.messages << build(:message, sender: sender, body: "<script>alert('toasty!);</script>")

    visit user_facebook_omniauth_authorize_path
    visit conversation_path(conversation, itinerary_id: itinerary.id)

    click_button I18n.t('conversations.form.send')

    expect(page).to have_css '.alert-danger'
  end

  it 'displays unread messages in the navbar', js: true do
    receiver = create :user, uid: '123456'
    sender = create :user
    itinerary = create :itinerary, user: receiver
    conversation = create :conversation, users: [receiver, sender], conversable: itinerary
    conversation.messages << build(:message, sender: sender, body: "<script>alert('toasty!);</script>")

    visit user_facebook_omniauth_authorize_path

    within('.navbar-notifications') do
      expect(page).to have_css '.unread-count'
      expect(page).to have_xpath "//span[@class='unread-count' and text()='1']"
      find('#notifications-conversations > a').click
      within('.popover') do
        expect(page).to have_content sender.to_s
        expect(page).to have_content "<script>alert('toasty!);</script>"
        expect(-> { page.driver.browser.switch_to.alert }).to raise_error Selenium::WebDriver::Error::NoAlertPresentError
      end
    end
  end

  context 'when visiting unread' do
    it 'redirects to conversations path' do
      visit user_facebook_omniauth_authorize_path

      visit unread_conversations_path

      expect(current_path).to eq conversations_path
    end
  end
end
