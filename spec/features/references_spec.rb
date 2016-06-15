# frozen_string_literal: true
require 'spec_helper'

describe 'References' do
  POSITIVE_ICON = 'span.fa.fa-thumbs-up'
  NEGATIVE_ICON = 'span.fa.fa-thumbs-down'

  let(:driver) { create :user }
  let(:passenger) { create :user }
  let(:itinerary) { create :itinerary, user: driver }

  def login_as_driver
    driver.update_attributes uid: '123456'

    visit user_facebook_omniauth_authorize_path
  end

  def login_as_passenger
    passenger.update_attributes uid: '123456'

    visit user_facebook_omniauth_authorize_path
  end

  it 'allows passengers to send references' do
    login_as_passenger
    body = 'Very good driver'

    visit new_user_reference_path(passenger, itinerary_id: itinerary.id)

    fill_in 'reference_body', with: body
    choose('reference_rating_1')

    click_button I18n.t('helpers.submit.create', model: Reference.model_name.human)
    expect(page).to have_content body
  end

  it 'rescues from creation errors' do
    login_as_passenger

    visit new_user_reference_path(passenger, itinerary_id: itinerary.id)

    click_button I18n.t('helpers.submit.create', model: Reference.model_name.human)
    expect(page).to have_css 'form .alert.alert-danger'
  end

  it 'allows users to view their own ones' do
    login_as_driver

    itineraries = create_list :itinerary, 3, user: driver
    passengers = create_list :user, 3

    references = []
    references[0] = build :reference, user: passengers[0], itinerary: itineraries[0]
    build :outgoing_reference, reference: references[0], rating: 1, body: 'Positive'
    references[0].save

    references[1] = build :reference, user: passengers[1], itinerary: itineraries[1]
    build :outgoing_reference, reference: references[1], rating: 0, body: 'Neutral'
    references[1].save

    references[2] = build :reference, user: passengers[2], itinerary: itineraries[2]
    build :outgoing_reference, reference: references[2], rating: -1, body: 'Negative'
    references[2].save

    visit user_references_path(driver)

    expect(page).to have_css('tbody > tr', count: 3)
    driver.itineraries.each_with_index do |_itinerary, index|
      row = find(:xpath, "//a[text()='#{references[index].outgoing.body}']/../..")
      expect(row).to_not be_nil
      expect(row).to have_css POSITIVE_ICON if references[index].outgoing.rating == 1
      expect(row).to have_css NEGATIVE_ICON if references[index].outgoing.rating == -1
    end
  end

  it 'allows drivers to answer references' do
    login_as_driver

    reference = build :reference, user: passenger, itinerary: itinerary
    build :outgoing_reference, reference: reference, rating: 1, body: 'Good Driver'
    reference.save
    driver.reload

    visit user_reference_path(driver, driver.references.first)

    click_button I18n.t('helpers.submit.update', model: Reference.model_name.human)

    expect(page).to have_css 'form .alert.alert-danger'

    fill_in 'reference_body', with: "Thanks\nMate!"
    choose('reference_rating_1')

    click_button I18n.t('helpers.submit.update', model: Reference.model_name.human)

    expect(page).to have_content 'Thanks'
  end
end
