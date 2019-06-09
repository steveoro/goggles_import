# frozen_string_literal: true

#
# = Admin model
#
#   - version:  6.400
#   - author:   Steve A.
#
class Admin < ApplicationRecord

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable

  devise :database_authenticatable, :trackable, :lockable
  #         :recoverable, :rememberable, :validatable, :timeoutable
  # [Steve, 20130716] Registerable module removed as-per-config of rails_admin gem:
  #         :registerable

  # Setup accessible (or protected) attributes for your model
  #  attr_accessible :name, :email, :description, :password, :password_confirmation

  include Rails.application.routes.url_helpers

  validates :name, presence: { length: { within: 1..20 }, allow_nil: false }
  validates :name, uniqueness: { message: :already_exists }

  validates :description, length: { maximum: 50 }

  #-----------------------------------------------------------------------------
  # Base methods:
  #-----------------------------------------------------------------------------
  #++

  # Utility method to retrieve the controller base route directly from an instance of the model
  def base_uri
    users_path( self )
  end

  # Computes a descriptive name associated with this data
  def full_name
    "#{name} (desc.: #{description})"
  end

  alias get_full_name full_name

  # to_s() override for debugging purposes:
  def to_s
    "[Admin: '#{full_name}']"
  end
  # ----------------------------------------------------------------------------

end
