require 'spec_helper'

describe 'auditserver' do
  context '' do
    let (:facts)
      { :kernel => 'Linux',
        :libpath_real => '/proj/cnshrepo/lib/linux',
        :fqdn => 'test.example.com',
        :architecture => 'x86_64',
        :is_virtual => 'true',
        :virtual    => 'xenu',
        :osfamily   => 'Redhat',
        :osversion  => '6.4',
        :memorytotal => '4 G',
        :processorcount => '4',
        }
    

    it { should include_class('auditserver') }
    
    it do 
      should contain_file('auditserver').with({
        'path'    => '/usr/bin/auditserver.pl',
        'owner'   => 'root',
        'group'   => 'root',
        'mode'    => '755',
        'content' => "template('auditserver/auditEISserver.erb')",
      })
     end


    it do 
      should contain_cron('auditserver').with({
        'command' => "/usr/bin/auditserver.pl cnsh",
        'user'    => 'root',
        'month'   => '11',
        'monthday' => '22',
        'hour'    => '12',
        'minute'  => '0',
      })
     end
  end
end
