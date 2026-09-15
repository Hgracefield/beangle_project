from fastapi import APIRouter
# from database.database import Dbconn
from pydantic import BaseModel
import pymysql
import config
from typing import List
from datetime import datetime

router = APIRouter()
	

class ReservationModel(BaseModel):
    reservation_id: int|None
    user_id: int
    station_id: int
    time:str
    is_cancel: int

def _normalize_time_string(raw_time: str) -> str:
    cleaned = raw_time.strip()
    if not cleaned:
        raise ValueError('time is empty')

    # Accept both "2026-04-03 12:30:00" and ISO strings such as
    # "2026-04-03T12:30:00" or "...Z".
    if cleaned.endswith('Z'):
        cleaned = cleaned[:-1] + '+00:00'

    parsed = datetime.fromisoformat(cleaned.replace(' ', 'T'))
    return parsed.strftime('%Y-%m-%d %H:%M:%S')

def connect():
    return pymysql.connect(
        host=config.DB_HOST,
        port=config.DB_PORT,
        user=config.DB_USER,
        password=config.DB_PASSWORD,
        database=config.DB_NAME,
        charset=config.DB_CHARSET,
        autocommit=False
    )

@router.get('/selectById/{id}')
async def get(id: int):
    conn = connect()
    curs = conn.cursor()

    sql = 'select * from reservation where reservation_id=%s' # (%s,%s,%s,%s)'
    curs.execute(sql,[id])
    rows = curs.fetchall()
    
    conn.close()
    column_names = [desc[0] for desc in curs.description]
    print(column_names)
    #결과물 dictionary 형태로 전환
    results = [dict(zip(column_names,row)) for row in rows]
    print(results)

    return {'results':results}


@router.get('/selectByUserId/{id}')
async def get(id:int):
    conn = connect()
    curs = conn.cursor()

    sql = 'select * from reservation where user_id=%s order by reservation_id desc' # (%s,%s,%s,%s)'
    curs.execute(sql,[id])
    rows = curs.fetchall()
    
    conn.close()
    column_names = [desc[0] for desc in curs.description]
    print(column_names)
    #결과물 dictionary 형태로 전환
    results = [dict(zip(column_names,row)) for row in rows]
    print(results)

    return {'results':results}


@router.get('/select')
async def get():
    conn = connect()
    curs = conn.cursor()

    sql = 'select * from reservation order by reservation_id desc' # (%s,%s,%s,%s)'
    curs.execute(sql,[])
    rows = curs.fetchall()
    
    conn.close()
    column_names = [desc[0] for desc in curs.description]
    print(column_names)
    #결과물 dictionary 형태로 전환
    results = [dict(zip(column_names,row)) for row in rows]
    print(results)

    return {'results':results}


@router.post('/inserts')
async def insert(data: List[ReservationModel]):
  
  print('=== Inserts Reservation ===')
  returnValue : int = 0
  try:
    conn = connect()
    curs = conn.cursor()

    for d in data:
        sql = 'INSERT INTO reservation(user_id, station_id, `time`, is_cancel) values(%s,%s,%s,%s)'
        normalized_time = _normalize_time_string(d.time)
        curs.execute(sql,[d.user_id, d.station_id, normalized_time, d.is_cancel])
    conn.commit()
    returnValue = 1

    
  except Exception as err:
    conn.rollback()
    returnValue = 0
    print('ERROR(INSERT): Rollbacked')
    print(err)
  finally:
     conn.close()
     return {'result':returnValue}


@router.post('/insert')
async def insert(data: ReservationModel):
  
  print('=== Insert Reservation ===')
  conn = None
  try:
    conn = connect()
    curs = conn.cursor()

    sql = 'INSERT INTO reservation(user_id, station_id, `time`, is_cancel) values(%s,%s,%s,%s)'
    normalized_time = _normalize_time_string(data.time)
    curs.execute(sql,[data.user_id, data.station_id, normalized_time, data.is_cancel])
    conn.commit()

    return {'result':1}
  except Exception as err:
    if conn is not None:
      conn.rollback()
    print('ERROR(INSERT): ')
    print(err)
    return {'result':0}
  finally:
    if conn is not None:
      conn.close()

@router.post('/update')
async def update(data: ReservationModel):
    conn = None
    try:
        print('=== update Reservation ===')
        conn = connect()
        curs = conn.cursor()

        sql = 'update reservation set station_id=%s, time=%s, is_cancel=%s where reservation_id=%s'
        normalized_time = _normalize_time_string(data.time)
        curs.execute(sql,[data.station_id, normalized_time, data.is_cancel,data.reservation_id])
        conn.commit()
        return {'result':1}
    except Exception as err:
       if conn is not None:
         conn.rollback()
       print('=== ERROR(UPDATE): ')
       print(err)
       return {'result':0}
    finally:
       if conn is not None:
         conn.close()

@router.post('/cancel')
async def cancel(data: ReservationModel):
    conn = None
    try:
        print('=== cancel Reservation ===')
        conn = connect()
        curs = conn.cursor()

        sql = 'update reservation set is_cancel=%s where reservation_id=%s and user_id=%s'
        curs.execute(sql,[1, data.reservation_id, data.user_id])
        conn.commit()
        return {'result':1}
    except Exception as err:
       if conn is not None:
         conn.rollback()
       print('=== ERROR(CANCEL): ')
       print(err)
       return {'result':0}
    finally:
       if conn is not None:
         conn.close()

@router.post('/delete')
async def delete(data: ReservationModel):
    conn = None
    try:
        print('=== delete Reservation ===')
        conn = connect()
        curs = conn.cursor()

        sql = 'delete from reservation where reservation_id=%s and user_id=%s'
        curs.execute(sql, [data.reservation_id, data.user_id])
        conn.commit()
        return {'result':1}
    except Exception as err:
       if conn is not None:
         conn.rollback()
       print('=== ERROR(DELETE): ')
       print(err)
       return {'result':0}
    finally:
       if conn is not None:
         conn.close()
