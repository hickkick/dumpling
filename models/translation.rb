require_relative '../db'

class Translation < Sequel::Model
    plugin :timestamps, update_on_create: true
    plugin :validation_helpers
  
    def validate
      super
      validates_presence [:locale, :key, :value]
      validates_unique [:locale, :key]
    end
end