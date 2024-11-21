#!/bin/bash

if [[ $1 == "test" ]]
then
  PSQL="psql --username=postgres --dbname=worldcuptest -t --no-align -c"
else
  PSQL="psql --username=vanpuffelen --dbname=postgres -t --no-align -c"
fi

#variables
dbname='worldcup';
t1_name='teams';
t1c1_name='team_id';
t1c1_cons='SERIAL PRIMARY KEY';
t1c2_name='name';
t1c2_cons='VARCHAR(30) UNIQUE NOT NULL';

t2_name='games';
t2c1_name='game_id';
t2c1_cons='SERIAL PRIMARY KEY';
t2c2_name='year';
t2c2_cons='INT NOT NULL';
t2c3_name='round';
t2c3_cons='VARCHAR(20) NOT NULL';
t2c4_name='winner_id';
t2c4_cons="INT NOT NULL REFERENCES $t1_name($t1c1_name)";
t2c5_name='opponent_id';
t2c5_cons="INT NOT NULL REFERENCES $t1_name($t1c1_name)";
t2c6_name='winner_goals';
t2c6_cons='INT NOT NULL';
t2c7_name='opponent_goals';
t2c7_cons='INT NOT NULL';

#check for existing database
resp=$($PSQL "select exists(
 SELECT datname FROM pg_catalog.pg_database WHERE lower(datname) = lower('$dbname')
);")

#create and connect new database
if [[ $resp == 'f' ]]
  then
    resp="$($PSQL "CREATE DATABASE $dbname;")"
    if [[ $resp == 'CREATE DATABASE' ]]
        then 
          resp=($($PSQL "\c $dbname"));
          if [[ ${resp[1]} == 'are' && ${resp[3]} == 'connected' ]]
            then 
              echo -e "\033[32m\nconnected to new database: $dbname\033[0m";
              PSQL="psql --username=vanpuffelen --dbname=$dbname -t --no-align -c"
            else
              echo -e "\033[35m\ndb connection failed\033[0m";
              exit 1;
          fi
        else
          echo -e "\033[35m\ndb creation failed\033[0m";
          exit 1;
    fi
  else 
    echo -e "\033[35m\ndatabase $dbname already exists\033[0m";
    exit 1;
fi

#create tables 'teams' & 'games'
resp="$($PSQL "CREATE TABLE $t1_name($t1c1_name $t1c1_cons, $t1c2_name $t1c2_cons)")";
if [[ $resp == 'CREATE TABLE' ]]
  then echo -e "\n\033[32mtable '$t1_name' added\033[0m"
fi
resp="$($PSQL "CREATE TABLE $t2_name($t2c1_name $t2c1_cons, $t2c2_name $t2c2_cons, $t2c3_name $t2c3_cons, $t2c4_name $t2c4_cons, $t2c5_name $t2c5_cons, $t2c6_name $t2c6_cons, $t2c7_name $t2c7_cons)")";
if [[ $resp == 'CREATE TABLE' ]]
  then echo -e "\n\033[32mtable '$t2_name' added\033[0m"
fi

#insert unique teams from csv file to teams table;
fill_teams () {
  IFS=','
  filelength=$(wc -l < ./games.csv)
  cat ./games.csv | for (( i = 0; i < $filelength; i++))
    do
      read y r w o rest
        if [[ $w != 'winner' ]]
          then
            teams+="('$w').";
            teams+="('$o').";
        fi
        if [[ $i == $(( $filelength - 1)) ]]
          then
            IFS=' ';
            uniqstring=$(printf "%s\n" "$(echo $teams | tr '.' '\n')" | sort -u | tr '\n' ',');
            resp=($($PSQL "INSERT INTO $t1_name($t1c2_name) VALUES${uniqstring%?}";));
            if [[ ${resp[0]} == 'INSERT' ]]
              then 
                echo -e "\n\033[32m${resp[2]} records added to $t1_name\033[0m";
              else 
                echo -e "\033[35m\ninsertion $t1_name failed\033[0m";
                exit 1;
            fi
        fi
    done
}
fill_teams;

#insert game data from csv file to games table;
fill_games () {
    PSQL="psql --username=vanpuffelen --dbname=$dbname -t --no-align --record-separator=. -c"
    IFS=' ';
    db_teamsarr=($($PSQL "SELECT name FROM teams;" | tr ' ' '*' | tr '.' ' '));
    db_idsarr=($($PSQL "SELECT team_id FROM teams;" | tr '.' ' '));
    db_idsarrLength=${#db_idsarr[*]};
    filelength=$(wc -l < ./games.csv);
    IFS=",";
    cat ./games.csv | for (( i = 0; i < $filelength; i++)) 
        do
            read y r w o wg og
            if [[ $y != 'year' ]]
                then
                    w=$(echo $w | tr ' ' '*';);
                    o=$(echo $o | tr ' ' '*';);
                    for (( j = 0; j < $db_idsarrLength; j++))
                        do
                            if [[ ${db_teamsarr[j]} == $w ]]
                                then 
                                    w_id="${db_idsarr[j]}";
                            fi
                            if [[ ${db_teamsarr[j]} == $o ]]
                                then 
                                    o_id="${db_idsarr[j]}";
                            fi
                        done
                    values+="($y,'$r',$w_id,$o_id,$wg,$og),";
            fi
            if [[ $i == $(($filelength - 1)) ]]
                then
                    IFS=' ';
                    values=$(echo ${values%?});
                    resp=($($PSQL "INSERT INTO $t2_name($t2c2_name,$t2c3_name,$t2c4_name,$t2c5_name,$t2c6_name,$t2c7_name) VALUES $values"));
                    if [[ ${resp[0]} == 'INSERT' ]]
                        then 
                            echo -e "\n\033[32m${resp[2]} records added to $t2_name\033[0m";
                    else 
                            echo -e "\033[35m\ninsertion $t2_name failed\033[0m";
                            exit 1;
                    fi
            fi
        done
}
fill_games;

