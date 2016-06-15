# frozen_string_literal: true
class Feedback
  include Mongoid::Document
  include Mongoid::Timestamps

  TYPE = %w(bug idea).freeze
  STATUS = ['open', 'fixed', 'in progress', 'not applicable'].freeze

  belongs_to :user
  delegate :name, to: :user, prefix: true, allow_nil: true

  field :type, type: String, default: 'bug'
  field :message, type: String
  field :url, type: String
  field :status, type: String, default: 'open'

  validates :type, inclusion: TYPE, presence: true
  validates :status, inclusion: STATUS, presence: true
  validates :message, presence: true

  def fixed?
    status == 'fixed'
  end
end
