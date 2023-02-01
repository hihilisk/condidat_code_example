# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  about                  :text
#  active                 :boolean          default(FALSE)
#  admin                  :boolean          default(FALSE)
#  avatar_background      :string
#  business_phone         :string
#  collegues_count        :integer          default(0), not null
#  companies_count        :integer          default(0), not null
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  current_step           :string
#  current_title          :string
#  description            :text
#  email                  :string           default(""), not null
#  email_visible          :boolean          default(TRUE)
#  encrypted_password     :string           default(""), not null
#  ext_phone              :string
#  facebook               :string
#  feedbacks_count        :integer          default(0), not null
#  instagram              :string
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  linkedin               :string
#  location               :string
#  month                  :string
#  name                   :string
#  phone                  :string
#  properties_count       :integer          default(0), not null
#  public_email           :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  show_tour              :boolean          default(TRUE)
#  sign_in_count          :integer          default(0), not null
#  slug                   :string
#  surname                :string
#  twitter                :string
#  unconfirmed_email      :string
#  website                :string
#  year                   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  company_id             :bigint
#
# Indexes
#
#  index_users_on_company_id            (company_id)
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_slug                  (slug) UNIQUE
#
class User < ApplicationRecord
  include Stepable

  extend FriendlyId

  default_scope -> { with_attached_avatar }

  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable, :trackable, :confirmable,
         :jwt_authenticatable, :omniauthable, jwt_revocation_strategy: JwtDenylist, omniauth_providers: [:linkedin]

  PORTFOLIO_SET_UP_STEPS = %w[after-confirmation base-information expertise picture-upload review].freeze
  AVATAR_BACKGROUND = %w[#1E90FF #6D6E71 #FFA551 #F2F2F2].freeze

  has_one_attached :avatar

  has_one :company, -> { where active: false }, dependent: :destroy, inverse_of: :user

  has_many :expertises, as: :expertiseable, dependent: :destroy
  has_many :industries, class_name: 'Roles::Industry', through: :expertises
  has_many :disciplines, class_name: 'Roles::Discipline', through: :expertises
  has_many :specialities, class_name: 'Roles::Speciality', through: :expertises
  accepts_nested_attributes_for :expertises

  with_options(dependent: :destroy) do
    has_many :authorizations
    has_many :favorites
    has_many :notifications
    has_many :feedbacks
    has_many :experiences
    has_many :educations
    has_many :certificates
    has_many :comparison_groups
  end

  has_many :user_companies, dependent: :destroy
  has_many :companies, through: :user_companies

  has_many :user_properties, dependent: :destroy
  has_many :properties, through: :user_properties

  validates :current_step, inclusion: PORTFOLIO_SET_UP_STEPS, allow_nil: true, on: :update

  validates :avatar,
            content_type: %w[image/png image/jpg image/jpeg],
            size: { less_than: 10.megabytes, message: 'The image must not exceed 10 megabyte in size' }

  after_validation :set_avatar_background, on: :create

  scope :order_by_params, ->(order_column = 'id', order_by = 'asc') { order("#{order_column} #{order_by}") }

  friendly_id :full_name, use: %i[sequentially_slugged finders history]

  searchkick searchable: %i[full_name], word_start: %i[full_name]

  def self.find_for_oauth(auth)
    FindForOauthService.call(auth)
  end

  def full_name
    "#{name} #{surname}".strip
  end

  def search_serializer_class
    Search::UserFavoriteSerializer
  end

  private

  def search_data
    attributes.merge(
      full_name: full_name
    )
  end

  def set_avatar_background
    self.avatar_background = AVATAR_BACKGROUND.sample
  end
end
