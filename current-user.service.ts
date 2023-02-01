import { Injectable } from '@angular/core';
import {
  HttpClient,
  HttpEvent,
  HttpEventType,
  HttpHeaders,
  HttpProgressEvent,
  HttpRequest,
} from '@angular/common/http';

import { Observable, Observer, Subject, Subscription } from 'rxjs';
import { map, last, catchError } from 'rxjs/operators';
import { Model } from 'src/app/shared/tsmodels/tsmodels';
import { User, Timing, IUserEdit, InvitationRespone, InviteUser } from '@models';
import { OWNER } from '@consts';

@Injectable()
export class CurrentUserService extends User {
  private readonly _apiProfilePath = '/api/profile';
  private readonly _apiUsersPath = '/api/users';
  private readonly _apiAdminUsersPath = '/api/admin/users';
  public progressSubject = new Subject<number>();
  public avatarSubscription: Subscription;

  constructor(private readonly _http: HttpClient) {
    super();
  }

  public static setTokenByHeaders(headers: HttpHeaders, beforeImpersonate = false): void {
    let token: string = headers.get('authorization');
    token = token.substr(token.indexOf(' ') + 1);
    localStorage.setItem('token', token);
    if (beforeImpersonate) {
      localStorage.setItem('beforeImpersonatedToken', token);
    }
  }

  public isLoggedIn(): boolean {
    return !!this.id;
  }

  public load(): Observable<User> {
    return this._http.get(this._apiProfilePath, { observe: 'response' }).pipe(
      map((res: any) => {
        this._fromJSON(res.body.user);
        return this;
      })
    );
  }

  public updateSettings(userData: User = this): Observable<User> {
    if (typeof userData.birthday !== 'undefined') {
      const bDay = new Date(userData.birthday);
      const bDayUtc = new Date(Date.UTC(bDay.getFullYear(), bDay.getMonth(), bDay.getDate()));
      userData.birthday = bDayUtc.toDateString();
    }
    const data = { user: userData._toJSON() };

    return this._http.put(this._apiProfilePath, data, { observe: 'response' }).pipe(
      map((res: any) => {
        this._fromJSON(res.body.user);
        return this;
      })
    );
  }

  public loadDocuments(token: string): Observable<InvitationRespone> {
    return this._http
      .get(`${this._apiUsersPath}/${token}/invitation`)
      .pipe(map((resp) => new InvitationRespone(resp)));
  }

  public acceptInvite(token: string, user: InviteUser): Observable<boolean> {
    const params = { user: user._toJSON() };

    return this._http
      .put(`${this._apiUsersPath}/${token}/invitation`, params, { observe: 'response' })
      .pipe(
        map((resp) => {
          CurrentUserService.setTokenByHeaders(resp.headers);
          return true;
        })
      );
  }

  public edit(): Observable<IUserEdit> {
    return this._http.get(`${this._apiProfilePath}/edit`).pipe(
      map((res: any) => {
        const timings = Model.newCollection(Timing, res.timings);
        return { timings };
      })
    );
  }

  public sendPasswordReset(email: string): Observable<boolean> {
    const data = { user: { email } };

    return this._http
      .post(`${this._apiUsersPath}/password`, data, { observe: 'response' })
      .pipe(map(() => true));
  }

  public setNewPassword(password: string, token: string): Observable<boolean> {
    const data = {
      user: {
        password,
        password_confirmation: password,
        reset_password_token: token,
      },
    };

    return this._http
      .put(`${this._apiUsersPath}/password`, data, { observe: 'response' })
      .pipe(map(() => true));
  }

  public signIn(email: string, password: string): Observable<boolean> {
    const data = { user: { email, password } };

    return this._http.post(`${this._apiUsersPath}/sign_in`, data, { observe: 'response' }).pipe(
      map((resp) => {
        this._fromJSON(resp.body);
        CurrentUserService.setTokenByHeaders(resp.headers, true);
        return true;
      })
    );
  }

  public impersonateUser(user: User): Observable<boolean> {
    return this._http
      .post(`${this._apiAdminUsersPath}/${user.id}/impersonate`, user.id, { observe: 'response' })
      .pipe(
        map((resp) => {
          this._fromJSON(resp.body);
          localStorage.setItem('impersonatedMode', 'true');
          CurrentUserService.setTokenByHeaders(resp.headers);
          return true;
        })
      );
  }

  public stopImpersonateUser(): Observable<boolean> {
    return this._http.post(`${this._apiAdminUsersPath}/stop_impersonating`, this.id).pipe(
      map(() => {
        const token: string = localStorage.getItem('beforeImpersonatedToken');
        if (token) {
          localStorage.setItem('token', token);
          localStorage.removeItem('impersonatedMode');
        }
        return !!token;
      })
    );
  }

  public signOut(): Observable<boolean> {
    return this._http.delete(`${this._apiUsersPath}/sign_out`).pipe(
      map(() => {
        localStorage.removeItem('token');
        localStorage.removeItem('beforeImpersonatedToken');
        localStorage.removeItem('impersonatedMode');
        return true;
      })
    );
  }

  public uploadAvatar(image: File): Observable<User> {
    const data = new FormData();
    data.append('avatar', image, image.name);

    const req = new HttpRequest('PUT', `${this._apiProfilePath}/update_avatar`, data, {
      reportProgress: true,
    });

    return new Observable((observer: Observer<User>) => {
      this.avatarSubscription = this._http
        .request(req)
        .pipe(
          // eslint-disable-next-line consistent-return
          map((e: HttpEvent<any>) => {
            if (e.type === HttpEventType.UploadProgress) {
              const progress = e as HttpProgressEvent;
              this.progressSubject.next(Math.round((100 * progress.loaded) / progress.total));
            } else if (e.type === HttpEventType.Response) {
              return e.body;
            }
          }),
          last(null),
          catchError((error) => error)
        )
        .subscribe(
          (res: any) => {
            this._fromJSON(res.user);
            observer.next(this);
            observer.complete();
          },
          (error) => observer.error(error)
        );
    });
  }

  public acceptTerms(): Observable<User> {
    return this._http.post(`/api/agreement/accept`, {}).pipe(
      map((res: any) => {
        this._fromJSON(res.user);
        return this;
      })
    );
  }

  public hasPermissions(permissions: string | string[]): boolean {
    if (this.email === OWNER) {
      return true;
    }
    if (typeof permissions === 'string') {
      const [subject, action] = permissions.split(':');
      return !!this.permissions.find((p) => p.subject === subject && p.action === action);
    }
    if (Array.isArray(permissions)) {
      return permissions.every((permission) => this.hasPermissions(permission));
    }
    return false;
  }

  public hasSomePermissions(permissions: string | string[]): boolean {
    if (this.email === OWNER) {
      return true;
    }
    if (typeof permissions === 'string') {
      const [subject, action] = permissions.split(':');
      return !!this.permissions.find((p) => p.subject === subject && p.action === action);
    }
    if (Array.isArray(permissions)) {
      return permissions.some((permission) => this.hasSomePermissions(permission));
    }
    return false;
  }
}
