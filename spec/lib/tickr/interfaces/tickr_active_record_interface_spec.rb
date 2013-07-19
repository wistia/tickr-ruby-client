require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

require File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'lib', 'tickr', 'interfaces', 'tickr_active_record_interface')

require 'active_record'

describe TickrActiveRecordInterface do
  before do
    TickrClient.any_instance.stub :fetch_tickets
    $tickr = TickrClient.new({servers: [{}]})

    ActiveRecord::Base.establish_connection adapter: :sqlite3, database: ':memory:'
    with_silenced_output do
      ActiveRecord::Schema.define do
        create_table 'test_models' do |t|
          t.datetime 'created_at'
          t.datetime 'updated_at'
        end
      end
    end

    class TestModel < ActiveRecord::Base
      include TickrActiveRecordInterface
    end
  end

  it 'parent accepts ID in place of an autoincrement value' do
    last_obj = TestModel.create!
    last_id = last_obj.id
    new_id = last_id + 5
    new_obj = TestModel.create! id: new_id
    new_obj.id.should_not == last_id + 1
    new_obj.id.should == new_id
  end
  it 'parent creates ID from tickr' do
    $tickr.stub(:get_ticket).and_return(115010)
    TestModel.create!.id.should == 115010
  end
end
