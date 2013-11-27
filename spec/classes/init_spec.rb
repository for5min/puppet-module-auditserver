require 'spec_helper'

describe 'auditserver' do
  context 'set params and facts' do
    let (:params) {{ :site  => 'cnsh' }}
    
    it { should include_class('auditserver') }
    
    it {
      should contain_file('auditserver_pl').with({
        'path'    => '/usr/bin/auditserver.pl',
        'owner'   => 'root',
        'group'   => 'root',
        'mode'    => '755',
      })
    }


    it {
      should contain_cron('auditserver_run').with({
        'command'  => "/usr/bin/auditserver.pl cnsh",
        'user'     => 'root',
      })
    }
    
  end
  
end
