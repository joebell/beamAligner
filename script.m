% script.m
% al.gantry.goto([0,0,0,0]);
% al.gantry.waitForMove();
% al.scanAxis(2, -60000, 60000, 25, false, false);
% 
% al.gantry.goto(1,25000);
% al.gantry.waitForMove();
% al.scanAxis(2, -60000, 60000, 25, false, false);
% 
% al.gantry.goto(1,-25000);
% al.gantry.waitForMove();
% al.scanAxis(2, -60000, 60000, 25, false, false);
% 
% al.gantry.goto(1,0);
% al.gantry.waitForMove();
% al.scanAxis(2, -60000, 60000, 25, false, false);
% 
% al.scanAxis(2, 60000, -60000, 25, false, false);
% al.saveFig('170303-Yalign.pdf')

% al.clearTrackData();
% 
% al.gantry.goto([0,0,0,0]);
% al.gantry.waitForMove();
% al.scanAxis(1, -25000, 25000, 25, false, false);
% 
% al.gantry.goto(2,25000);
% al.gantry.waitForMove();
% al.scanAxis(1, -25000, 25000, 25, false, false);
% 
% al.gantry.goto(2,-25000);
% al.gantry.waitForMove();
% al.scanAxis(1, -25000, 25000, 25, false, false);
% 
% al.gantry.goto(2,0);
% al.gantry.waitForMove();
% al.scanAxis(1, -25000, 25000, 25, false, false);
% 
% al.scanAxis(1, 25000, -25000, 25, false, false);
% al.saveFig('170303-Xalign.pdf')


al.clearTrackData();

al.gantry.goto([0,0,0,0]);
al.gantry.waitForMove();
al.scanAxis(0, -18, 18, 25, false, false);

al.gantry.goto(2,25000);
al.gantry.waitForMove();
al.scanAxis(0, -18, 18, 25, false, false);

al.gantry.goto(2,-25000);
al.gantry.waitForMove();
al.scanAxis(0, -18, 18, 25, false, false);

al.gantry.goto(2,0);
al.gantry.goto(1,25000);
al.gantry.waitForMove();
al.scanAxis(0, -18, 18, 25, false, false);

al.gantry.goto(1,-25000);
al.gantry.waitForMove();
al.scanAxis(0, -18, 18, 25, false, false);

al.gantry.goto([0,0,0,0]);
al.gantry.waitForMove();
al.scanAxis(0, -18, 18, 25, false, false);

al.scanAxis(0, 18, -18, 25, false, false);
al.saveFig('170303-Ralign.pdf')



