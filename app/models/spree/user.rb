module Spree
  class User < Spree::Base
    include UserAddress
    include UserMethods
    include UserPaymentSource

    devise :database_authenticatable, :recoverable,
           :rememberable, :trackable, :encryptable, encryptor: 'authlogic_sha512'
    devise :confirmable if Spree::Auth::Config[:confirmable]
    devise :validatable if Spree::Auth::Config[:validatable]
    devise :registerable if Spree::Auth::Config[:registerable]

    acts_as_paranoid
    after_destroy :scramble_email_and_password

    before_validation :set_login

    users_table_name = User.table_name
    roles_table_name = Role.table_name

    scope :admin, -> { includes(:spree_roles).where("#{roles_table_name}.name" => "admin") }

    def self.admin_created?
      User.admin.exists?
    end

    def admin?
      has_spree_role?('admin')
    end

    def self.send_reset_password_instructions(attributes={}, current_store)
      recoverable = find_or_initialize_with_errors(reset_password_keys, attributes, :not_found)
      recoverable.send_reset_password_instructions(current_store) if recoverable.persisted?
      recoverable
    end

    def send_reset_password_instructions(current_store)
      token = set_reset_password_token
      send_reset_password_instructions_notification(token, current_store.id)

      token
    end

    def send_reset_password_instructions_notification(token, current_store_id)
      send_devise_notification(:reset_password_instructions, token, { current_store_id: current_store_id })
    end

    protected

    def password_required?
      !persisted? || password.present? || password_confirmation.present?
    end

    private

    def set_login
      # for now force login to be same as email, eventually we will make this configurable, etc.
      self.login ||= email if email
    end

    def scramble_email_and_password
      self.email = SecureRandom.uuid + "@example.net"
      self.login = email
      self.password = SecureRandom.hex(8)
      self.password_confirmation = password
      save
    end
  end
end
