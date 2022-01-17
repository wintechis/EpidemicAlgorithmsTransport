/**
* Name: Station_Item
* Author: Sebastian Schmid
* Description: defines items (entities that are transported) and stations (sources and destination for items)
* Tags: 
*/

model things

import "ShopFloor_Grid.gaml"

global {

	int no_station <- 4;
	int no_transporter <- 17;
	
	float cell_width<- 1.0 ;

	string selected_placement_mode <- placement_mode[0]; //default is 'strict'
	float strict_placement_factor <- 0.33 min:0.1 max:0.45; //for strict mode to influence placement	
	
	map<rgb, point> truth; //holds the objective truth of stations and their positions
	
	
	//flags to indicate what measures are evaluated
	bool performance <- false; 
	bool knowledge <- false;
	
	list<float> residue; //percentage of agents that did NOT get a specific update at the end of a disturbance cycle
	int total_traffic <- 0; //total amount of msgs sent by agents during the simulation
	int t_inj <- 0; //the last cycle where an update was injected
	
	
	init{					
		create station number: no_station returns: stations;
		
	
		//the strict coloring mode for the strict placement mode that only uses 4 stations
		
		list<rgb> col_tmp ;
		
		switch no_station{
			//Remark: we only support 4, 16 and 64 station right now
			match 4{
				
				col_tmp <- [#red,#blue,#green, #orange];
				
			}
			
			match 16{
				
				col_tmp <- [#red,
							#blue,
							#green,
							#orange,
							#salmon, 
							#sandybrown, 
							#seagreen, 
							#seashell, 
							#sienna, 
							#silver, 
							#skyblue, 
							#slateblue, 
							#slategray, 
							#slategrey, 
							#snow, 
							#springgreen];

			}
			
			match 64{
				
				
				col_tmp <- [#red,
					#darkseagreen,
					#darkslateblue,
					#darkslategray,
					#darkslategrey,
					#darkturquoise,
					#darkviolet,
					#deeppink,
					#deepskyblue,
					#dimgray,
					#dimgrey,
					#dodgerblue,
					#firebrick,
					#floralwhite,
					#forestgreen,
					#fuchsia,
					#gainsboro,
					#ghostwhite,
					#gold,
					#goldenrod,
					#gray,
					#green,
					#greenyellow,
					#grey,
					#honeydew,
					#hotpink,
					#indianred,
					#indigo,
					#ivory,
					#khaki,
					#lavender,
					#lavenderblush,
					#lawngreen,
					#lemonchiffon,
					#lightblue,
					#lightcoral,
					#lightcyan,
					#lightgoldenrodyellow,
					#lightgray,
					#lightgreen,
					#lightgrey,
					#lightpink,
					#lightsalmon,
					#lightseagreen,
					#lightskyblue,
					#lightslategray,
					#lightslategrey,
					#lightsteelblue,
					#lightyellow,
					#lime,
					#limegreen,
					#linen,
					#magenta,
					#maroon,
					#mediumaquamarine,
					#mediumblue,
					#mediumorchid,
					#mediumpurple,
					#mediumseagreen,
					#mediumslateblue,
					#mediumspringgreen,
					#mediumturquoise,
					#mediumvioletred,
					#midnightblue,
					#mintcream];
				
			}
			
			default{
				warn "Something went wrong during scenario init!!";
			}
			
		}
		
		int i <- 0 ;
		
		loop s over: station{
			
			ask s{
				
				proba_thing_creation <- 0.8; //fixed PROBABILITY of item creation here to 0.8
										
				accept_color <- col_tmp[i]; //the color we accept
				color <- accept_color; //the color we display
				
				add 0 at: col_tmp[i] to: delivered; //create a key::value pair in the delivered variable, corresponding to a color::amount_of_delivered_things_of_this_color pair later
			}
			
			i <- i+1;//to get next color
		}

		
		/*After the colors have been assigned, choose valid colors for thing production */
		ask stations{
			
			valid_colors <- delivered.keys - accept_color; //delivered keys holds the list of all colors used by stations, exclude my own color		
		}
		
		/*Place stations acc. to simulation settings */
	
		float factor <-  1/(sqrt(no_station)+1) with_precision 2; //strict_placement_factor;
		
		//distribute stations equally
		loop x from: 1 to: sqrt(no_station) {
		
			loop y from: 1 to: sqrt(no_station) {
							
				station[(x-1)*int(sqrt(no_station)) + (y-1)].my_cell <- shop_floor[int(floor(x*width*factor)),int(floor(y*width*factor))];
			
			}
			
		}
		
		//initialize stations with cell and location
		loop s over: stations{	

			ask s{
					location<-my_cell.location ;
				}	
		}
		

		//add stations colot and position to the "truth"
		ask station {
			
			add location at: accept_color to: truth;	
		}
	}


	/*For random color change of stations */
	//every "disturbance_cycles" cycles, we take the already given colors and switch them randomly around
	reflex change_station_colors when: (cycle > 1) and every(disturbance_cycles){
		
		list<rgb> col_tmp <- nil; //will hold all current colors
		ask station{
			col_tmp <- col_tmp + accept_color; //add your color to the list of all color
		}
		
		col_tmp <- shuffle(col_tmp); // shuffle randomly
		
		int i <- 0 ;
				
		loop s over: station{
			
			ask s{										
				accept_color <- col_tmp[i]; //assign possibly new color
				
				color <- accept_color; //the color we display
				valid_colors <- col_tmp - accept_color; //update items that may be created
				
				//sanity check for assignment of new color - manipulate item, if it has the same color as the station now...
				if(storage != nil and (storage.color = accept_color))
				{
					storage.color <- one_of(valid_colors); //choose a random valid one
				}
				 
			}
			
			i <- i+1;//to get next color
		}
		
		
		//update truth
		ask station {
			
			add location at: accept_color to: truth;	
		}
		
		t_inj <- cycle; //save injection cycle
	}
	
}


species item parent: superclass schedules:[]{
	rgb color <- #white;
	int cycle_created <- -1; //the cycle when this thing was created by a station
	int cycle_delivered <- -1; //the cycle when this thing was delivered to a accepting station via a transporter	

	aspect base{
		
		draw circle(cell_width*0.6) color: color border:#black;
	}
	
	init{
		cycle_created <- cycle; //set the current cycle as "creation date" for this thing
	
	}
	

}

species station parent: superclass schedules:[]{
	
	item storage<- nil; //if nil, then this storage is empty
	
	rgb accept_color <- nil; //colors that this stations accepts
	
	float proba_thing_creation <- 0.8; //probability that thing is created
	
	list<rgb> valid_colors <- []; //contains all colors that may be created (= all stations colors MINUS its own color)
	
	reflex create_things when: (storage = nil) and (flip(proba_thing_creation)){  
		create item number: 1 returns: t{
			location <- myself.location;	
			//create a thing based on the generated station colors
			color <- one_of(myself.valid_colors);		
		}

		storage <- t[0]; //there is only one thing created, therefore take first entry and assign it to storage
	}
	
	aspect base{
		draw square(2*cell_width) color: accept_color border:#black;
	}	
}
