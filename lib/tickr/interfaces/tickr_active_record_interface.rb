require 'active_record'

module TickrActiveRecordInterface
  def self.included(base)
    base.before_create :set_tickr_id

    private
    def set_tickr_id
      self.id ||= $tickr.get_ticket
    end
  end
end
