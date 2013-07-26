require 'active_record'

class TickrIdNotSetError < StandardError; end

module TickrActiveRecordInterface
  def self.included(base)
    base.before_create :set_tickr_id
    base.before_create :ensure_id_set

    private
    def set_tickr_id
      self.id ||= $tickr.get_ticket
    end
    def ensure_id_set
      raise TickrIdNotSetError if self.id.nil?
    end
  end
end
