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
    # Hard-set some nonincremental IDs.
    (TestModel.create! id: 1).id.should == 1
    (TestModel.create! id: 6).id.should == 6
  end
  it 'parent creates ID from tickr' do
    $tickr.stub(:get_ticket).and_return(115010)
    TestModel.create!.id.should == 115010
  end

  it 'raises an exception if we save a record with no ID' do
    obj = TestModel.new
    obj.id.should be_nil
    $tickr.stub(:get_ticket).and_return(nil)
    lambda{obj.save!}.should raise_error(TickrIdNotSetError)
  end
end
