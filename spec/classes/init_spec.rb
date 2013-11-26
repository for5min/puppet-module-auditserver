require 'spec_helper'

describe 'auditserver' do
  context 'set params and facts' do
    let (:params)
      {{ :file_name  => '/usr/bin/auditserver.pl', :site       => 'cnsh' }}
    
    it { should include_class('auditserver') }
    
    it {
      should contain_file('auditserver_pl').with({
        :path    => '/usr/bin/auditserver.pl',
        :owner   => 'root',
        :group   => 'root',
        :mode    => '755',
        :content => "template('auditserver/auditEISserver.erb')",
      })
    }


    it {
      should contain_cron('auditserver_run').with({
        :command  => "/usr/bin/auditserver.pl cnsh",
        :user     => 'root',
        :month    => '11',
        :monthday => '22',
        :hour     => '12',
        :minute   => '0',
      })
    }
    
  end
  
end
