require_relative '../db'

class MenuItem < Sequel::Model
  plugin :timestamps, update_on_create: true
end