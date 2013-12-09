!=================================================
! The flux module of SPS-dynamic-integrate
!-------------------------------------------------
! Version: 0.11
! Author: Zhu F.
! Email: lyricorpse@gmail.com
! Date: 2013-05-04 13:59:46 
! Copyright: This software is provided under a CC BY-NC-SA 3.0 License(http://creativecommons.org/licenses/by-nc-sa/3.0/deed.zh)
!=================================================
MODULE sp_module_tendency
USE sp_module_constant
USE sp_module_model
USE sp_module_gridvar
USE sp_module_debug
IMPLICIT NONE
!=================================================
! Tendency term
!----------------------
REAL(kd), DIMENSION(ims:ime,kms:kme) :: tend_u = undef, tend_w = undef
REAL(kd), DIMENSION(ims:ime,kms:kme) :: tend_pi_1 = undef, tend_theta = undef
!-------------------------------------------------
! Diffusion term
!----------------------
REAL(kd), DIMENSION(ims:ime,kms:kme) :: P2uPx2_u = undef, P2uPz2_u = undef
REAL(kd), DIMENSION(ims:ime,kms:kme) :: P2wPx2_w = undef, P2wPz2_w = undef
REAL(kd), DIMENSION(ims:ime,kms:kme) :: P2thetaPx2_w = undef, P2thetaPz2_w = undef
!-------------------------------------------------
! Conponents
!----------------------
REAL(kd), DIMENSION(ims:ime,kms:kme) :: rhou_pi = undef, rhouu_pi = undef
REAL(kd), DIMENSION(ims:ime,kms:kme) :: rhow_vir = undef, rhowu_vir = undef
REAL(kd), DIMENSION(ims:ime,kms:kme) :: rhou_vir = undef, rhouw_vir = undef
REAL(kd), DIMENSION(ims:ime,kms:kme) :: rhow_pi = undef, rhoww_pi = undef
REAL(kd), DIMENSION(ims:ime,kms:kme) :: rhoutheta_vir = undef, rhowtheta_pi = undef
REAL(kd), DIMENSION(ims:ime,kms:kme) :: urhotheta_u = undef, wrhotheta_w = undef
!----------------------
REAL(kd), DIMENSION(ims:ime,kms:kme) :: PrhouPx_u = undef, PrhouuPx_u = undef
REAL(kd), DIMENSION(ims:ime,kms:kme) :: PrhowPz_u = undef, PrhowuPz_u = undef, Ppi_1Px_u = undef
REAL(kd), DIMENSION(ims:ime,kms:kme) :: PrhouPx_w = undef, PrhouwPx_w = undef, PrhowPz_w = undef
REAL(kd), DIMENSION(ims:ime,kms:kme) :: PrhowwPz_w = undef, Ppi_1Pz_w = undef
REAL(kd), DIMENSION(ims:ime,kms:kme) :: PrhouthetaPx_w = undef, PrhowthetaPz_w = undef
REAL(kd), DIMENSION(ims:ime,kms:kme) :: PurhothetaPx_pi = undef, PwrhothetaPz_pi = undef
!=================================================
CONTAINS
!=================================================
SUBROUTINE tendency_u(Main,tend_u,uGrid,wGrid,piGrid,virGrid)
IMPLICIT NONE
TYPE(mainvar), INTENT(IN) :: Main
TYPE(grid), INTENT(IN) :: uGrid, wGrid, piGrid, virGrid
REAL(kd), DIMENSION(ims:ime,kms:kme), INTENT(OUT) :: tend_u
!=================================================
REAL(kd), DIMENSION(ims:ime,kms:kme) :: F_u
!-------------------------------------------------
REAL(kd), DIMENSION(ims:ime,kms:kme) :: uPuPx_u, wPuPz_u
REAL(kd), DIMENSION(ims:ime,kms:kme) :: fa, fb, fc, fd, fe, ff
!-------------------------------------------------
INTEGER :: i, k
!=================================================
! 1. F_u = - u p.u/p.x - w p.u/p.z + fv   (fv = 0.)
! 1.1. - u p.u/p.x = - 1/rho (p.rhouu/p.x - u p.rhou/p.x)
! 1.2. - w p.u/p.z = - 1/rho (p.rhouw/p.z - u p.rhow/p.z)
!-------------------------------------------------
! pi-grid - Middle-vars can be calculated on boundaries.
!-------------------------------------------------
CALL set_area_pi
CALL set_area_expand(expand)

!OMP PARALLEL DO
DO k = kmin, kmax
	DO i = imin, imax
		rhou_pi(i,k) = piGrid%rho_0(i,k)*piGrid%u(i,k)
	END DO
END DO
!OMP END PARALLEL DO

SELECT CASE (AdvectionScheme)
CASE (5)
	!OMP PARALLEL DO
	DO k = kmin, kmax
		DO i = imin, imax
			fa(i,k) = Main%u(i-1,k) + Main%u(i,k)
			fb(i,k) = Main%u(i-2,k) + Main%u(i+1,k)
			fc(i,k) = Main%u(i-3,k) + Main%u(i+2,k)
			rhouu_pi(i,k) = rhou_pi(i,k)/60.*(37*fa(i,k) - 8*fb(i,k) + fc(i,k))
			fd(i,k) = Main%u(i,k) - Main%u(i-1,k)
			fe(i,k) = Main%u(i+1,k) - Main%u(i-2,k)
			ff(i,k) = Main%u(i+2,k) - Main%u(i-3,k)
			rhouu_pi(i,k) = rhouu_pi(i,k) - ABS(piGrid%u(i,k))/60.*(10*fd(i,k) - 5*fe(i,k) + ff(i,k))
		END DO
	END DO
	!OMP END PARALLEL DO
CASE DEFAULT
	STOP "Wrong advection scheme!!!"
END SELECT
!-------------------------------------------------
! v(virtual)-grid
!-------------------------------------------------
CALL set_area_vir
CALL set_area_expand(expand)

!OMP PARALLEL DO
DO k = kmin, kmax
	DO i = imin, imax
		rhow_vir(i,k) = virGrid%rho_0(i,k)*virGrid%w(i,k)
	END DO
END DO
!OMP END PARALLEL DO

SELECT CASE (AdvectionScheme)
CASE (5)
	!OMP PARALLEL DO
	DO k = kmin, kmax
		DO i = imin, imax
			fa(i,k) = Main%u(i,k) + Main%u(i,k-1)
			fb(i,k) = Main%u(i,k+1) + Main%u(i,k-2)
			fc(i,k) = Main%u(i,k+2) + Main%u(i,k-3)
			rhowu_vir(i,k) = rhow_vir(i,k)/60.*(37*fa(i,k) - 8*fb(i,k) + fc(i,k))
			fd(i,k) = Main%u(i,k) - Main%u(i,k-1)
			fe(i,k) = Main%u(i,k+1) - Main%u(i,k-2)
			ff(i,k) = Main%u(i,k+2) - Main%u(i,k-3)
			rhowu_vir(i,k) = rhowu_vir(i,k) - ABS(virGrid%w(i,k))/60.*(10*fd(i,k) - 5*fe(i,k) + ff(i,k))
		END DO
	END DO
	!OMP END PARALLEL DO
CASE DEFAULT
	STOP "Wrong advection scheme!!!"
END SELECT
!-------------------------------------------------
! u-grid
!-------------------------------------------------
CALL ppx_u(rhou_pi,PrhouPx_u)
CALL ppx_u(rhouu_pi,PrhouuPx_u)
CALL ppzeta_u(rhow_vir,PrhowPz_u)
CALL ppzeta_u(rhowu_vir,PrhowuPz_u)
CALL ppx_u(Main%pi_1,Ppi_1Px_u)

CALL set_area_u
!OMP PARALLEL DO
DO k = kmin, kmax
	DO i = imin, imax
		
		uPuPx_u(i,k) = 1./uGrid%rho_0(i,k)*(PrhouuPx_u(i,k) - Main%u(i,k)*PrhouPx_u(i,k))
		wPuPz_u(i,k) = 1./uGrid%rho_0(i,k)*(PrhowuPz_u(i,k) - Main%u(i,k)*PrhowPz_u(i,k))
	
		F_u(i,k) = - uPuPx_u(i,k) - wPuPz_u(i,k)
		tend_u(i,k) = F_u(i,k) - Cp*uGrid%theta_0(i,k)*Ppi_1Px_u(i,k)
	END DO
END DO
!OMP END PARALLEL DO

IF (RunCase == 1 .OR. RunCase == 2) THEN
	!OMP PARALLEL DO
	DO k = kmin, kmax
		DO i = imin, imax
			P2uPx2_u(i,k) = (Main%u(i+1,k) + Main%u(i-1,k) - 2*Main%u(i,k))/dx/dx
			P2uPz2_u(i,k) = (Main%u(i,k+1) + Main%u(i,k-1) - 2*Main%u(i,k))/dz/dz
			
			tend_u(i,k) = tend_u(i,k) + Km*(P2uPx2_u(i,k) + P2uPz2_u(i,k)) ! Add diffusion term.
		END DO
	END DO
	!OMP END PARALLEL DO
END IF
	
!-------------------------------------------------
IF (ANY(ISNAN(F_u(its:ite,kts:kte)))) STOP "SOMETHING IS WRONG WITH F_u!!!"
!=================================================
END SUBROUTINE tendency_u
!=================================================

!=================================================
SUBROUTINE tendency_w(Main,tend_w, uGrid, wGrid, piGrid, virGrid)
IMPLICIT NONE
TYPE(mainvar), INTENT(IN) :: Main
TYPE(grid), INTENT(IN) :: uGrid, wGrid, piGrid, virGrid
REAL(kd), DIMENSION(ims:ime,kms:kme), INTENT(OUT) :: tend_w
!=================================================
REAL(kd), DIMENSION(ims:ime,kms:kme) :: F_w
!-------------------------------------------------
REAL(kd), DIMENSION(ims:ime,kms:kme) :: uPwPx_w, wPwPz_w
REAL(kd), DIMENSION(ims:ime,kms:kme) :: fa, fb, fc, fd, fe, ff
!-------------------------------------------------
INTEGER :: i, k
!=================================================
! 2. F_w = - u p.w/p.x - w p.w/p.z + g(theta_1/theta_0)
! 2.1. - u p.w/p.x = - 1/rho (p.rhouw/p.x - w p.rhou/p.x)
! 2.2. - w p.w/p.z = - 1/rho (p.rhoww/p.z - w p.rhow/p.z)
!-------------------------------------------------
! v(virtual)-grid
!-------------------------------------------------
CALL set_area_vir
CALL set_area_expand(expand)

!OMP PARALLEL DO
DO k = kmin, kmax
	DO i = imin, imax
		rhou_vir(i,k) = virGrid%rho_0(i,k)*virGrid%u(i,k)
	END DO
END DO
!OMP END PARALLEL DO

SELECT CASE (AdvectionScheme)
CASE (5)
	!OMP PARALLEL DO
	DO k = kmin, kmax
		DO i = imin, imax
			fa(i,k) = Main%w(i,k) + Main%w(i+1,k)
			fb(i,k) = Main%w(i-1,k) + Main%w(i+2,k)
			fc(i,k) = Main%w(i-2,k) + Main%w(i+3,k)
			rhouw_vir(i,k) = rhou_vir(i,k)/60.*(37*fa(i,k) - 8*fb(i,k) + fc(i,k))
			fd(i,k) = Main%w(i+1,k) - Main%w(i,k)
			fe(i,k) = Main%w(i+2,k) - Main%w(i-1,k)
			ff(i,k) = Main%w(i+3,k) - Main%w(i-2,k)
			rhouw_vir(i,k) = rhouw_vir(i,k) - ABS(virGrid%u(i,k))/60.*(10*fd(i,k) - 5*fe(i,k) + ff(i,k))
		END DO
	END DO
	!OMP END PARALLEL DO
CASE DEFAULT
	STOP "Wrong advection scheme!!!"
END SELECT
!-------------------------------------------------
! pi-grid
!-------------------------------------------------
CALL set_area_pi
CALL set_area_expand(expand)

!OMP PARALLEL DO
DO k = kmin, kmax
	DO i = imin, imax
		rhow_pi(i,k) = piGrid%rho_0(i,k)*piGrid%w(i,k)
	END DO
END DO
!OMP END PARALLEL DO

SELECT CASE (AdvectionScheme)
CASE (5)
	!OMP PARALLEL DO
	DO k = kmin, kmax
		DO i = imin, imax
			fa(i,k) = Main%w(i,k) + Main%w(i,k+1)
			fb(i,k) = Main%w(i,k-1) + Main%w(i,k+2)
			fc(i,k) = Main%w(i,k-2) + Main%w(i,k+3)
			rhoww_pi(i,k) = rhow_pi(i,k)/60.*(37*fa(i,k) - 8*fb(i,k) + fc(i,k))
	
			fd(i,k) = Main%w(i,k+1) - Main%w(i,k)
			fe(i,k) = Main%w(i,k+2) - Main%w(i,k-1)
			ff(i,k) = Main%w(i,k+3) - Main%w(i,k-2)
			rhoww_pi(i,k) = rhoww_pi(i,k) - ABS(piGrid%w(i,k))/60.*(10*fd(i,k) - 5*fe(i,k) + ff(i,k))
		END DO
	END DO
	!OMP END PARALLEL DO
CASE DEFAULT
	STOP "Wrong advection scheme!!!"
END SELECT
!-------------------------------------------------
! w-grid 
!-------------------------------------------------
CALL ppx_w(rhou_vir,PrhouPx_w)
CALL ppx_w(rhouw_vir,PrhouwPx_w)
CALL ppzeta_w(rhow_pi,PrhowPz_w)
CALL ppzeta_w(rhoww_pi,PrhowwPz_w)
CALL ppzeta_w(Main%pi_1,Ppi_1Pz_w)

CALL set_area_w
!OMP PARALLEL DO
DO k = kmin, kmax
	DO i = imin, imax

		uPwPx_w(i,k) = 1./wGrid%rho_0(i,k)*(PrhouwPx_w(i,k) - Main%w(i,k)*PrhouPx_w(i,k))
		wPwPz_w(i,k) = 1./wGrid%rho_0(i,k)*(PrhowwPz_w(i,k) - Main%w(i,k)*PrhowPz_w(i,k))

		F_w(i,k) = - uPwPx_w(i,k) - wPwPz_w(i,k) + g*wGrid%theta_1(i,k)/wGrid%theta_0(i,k)
		tend_w(i,k) = F_w(i,k) - Cp*wGrid%theta_0(i,k)*Ppi_1Pz_w(i,k)
	END DO
END DO
!OMP END PARALLEL DO

IF (RunCase == 1 .OR. RunCase == 2) THEN
	!OMP PARALLEL DO
	DO k = kmin, kmax
		DO i = imin, imax
			P2wPx2_w(i,k) = (Main%w(i+1,k) + Main%w(i-1,k) - 2*Main%w(i,k))/dx/dx
			P2wPz2_w(i,k) = (Main%w(i,k+1) + Main%w(i,k-1) - 2*Main%w(i,k))/dz/dz
			
			tend_w(i,k) = tend_w(i,k) + Km*(P2wPx2_w(i,k) + P2wPz2_w(i,k)) ! Add diffusion term.
		END DO
	END DO
	!OMP END PARALLEL DO
END IF
!-------------------------------------------------
IF (ANY(ISNAN(F_w(its:ite,kts:kte)))) STOP "SOMETHING IS WRONG WITHT F_w!!!"
!=================================================
END SUBROUTINE tendency_w
!=================================================


!=================================================
SUBROUTINE tendency_pi(Main,tend_pi_1,uGrid,wGrid,piGrid,virGrid )
IMPLICIT NONE
TYPE(mainvar), INTENT(IN) :: Main
TYPE(grid), INTENT(IN) :: uGrid, wGrid, piGrid, virGrid
REAL(kd), DIMENSION(ims:ime,kms:kme), INTENT(OUT) :: tend_pi_1
!=================================================
REAL(kd), DIMENSION(ims:ime,kms:kme) :: F_pi
INTEGER :: i, k
!=================================================
! 5.1 F_pi = - c^2/(rho_0*theta_0^2)*(PurhothetaPx + PwrhothetaPz)
!-------------------------------------------------
CALL set_area_u
CALL set_area_expand(expand)

!OMP PARALLEL DO
DO k = kmin, kmax
	DO i = imin, imax
		urhotheta_u(i,k) = Main%u(i,k)*uGrid%rho_0(i,k)*uGrid%theta_0(i,k)
	END DO
END DO
!OMP END PARALLEL DO

CALL set_area_w
CALL set_area_expand(expand)

!OMP PARALLEL DO
DO k = kmin, kmax
	DO i = imin, imax
		wrhotheta_w(i,k) = Main%w(i,k)*wGrid%rho_0(i,k)*wGrid%theta_0(i,k)
	END DO
END DO
!OMP END PARALLEL DO

CALL ppx_pi(urhotheta_u,PurhothetaPx_pi)
CALL ppzeta_pi(wrhotheta_w,PwrhothetaPz_pi)

CALL set_area_pi
!OMP PARALLEL DO
DO k = kmin, kmax
	DO i = imin, imax
		
		F_pi(i,k) = - cs*cs/Cp/piGrid%rho_0(i,k)/piGrid%theta_0(i,k)/piGrid%theta_0(i,k)*(PurhothetaPx_pi(i,k) + PwrhothetaPz_pi(i,k))
		tend_pi_1(i,k) = F_pi(i,k)
	END DO
END DO
!OMP END PARALLEL DO
!-------------------------------------------------
IF (ANY(ISNAN(F_pi(its:ite,kts:kte)))) STOP "SOMETHING IS WRONG WITH F_theta!!!"
!=================================================
END SUBROUTINE tendency_pi
!=================================================

!=================================================
SUBROUTINE tendency_theta(Main,tend_theta,uGrid,wGrid,piGrid,virGrid)
IMPLICIT NONE
TYPE(mainvar), INTENT(IN) :: Main
TYPE(grid), INTENT(IN) :: uGrid, wGrid, piGrid, virGrid
REAL(kd), DIMENSION(ims:ime,kms:kme), INTENT(OUT) :: tend_theta
!=================================================
REAL(kd), DIMENSION(ims:ime,kms:kme) :: F_theta
!-------------------------------------------------
REAL(kd), DIMENSION(ims:ime,kms:kme) :: uPthetaPx_w, wPthetaPz_w
REAL(kd), DIMENSION(ims:ime,kms:kme) :: fa, fb, fc, fd, fe, ff
!-------------------------------------------------
INTEGER :: i, k
!=================================================
! 3. F_theta = - u p.theta/p.x - w p.theta/p.z
! 3.1. - u p.theta/p.x = - 1/rho (p.rhoutheta/p.x - theta p.rhou/p.x)
! 3.2. - w p.w/p.z = - 1/rho (p.rhothetaw/p.z - theta p.rhow/p.z)
!-------------------------------------------------
! v(virtual)-grid
!-------------------------------------------------
CALL set_area_vir
CALL set_area_expand(expand)

SELECT CASE (AdvectionScheme)
CASE (5)
	!OMP PARALLEL DO
	DO k = kmin, kmax
		DO i = imin, imax
			fa(i,k) = Main%theta(i,k) + Main%theta(i+1,k)
			fb(i,k) = Main%theta(i-1,k) + Main%theta(i+2,k)
			fc(i,k) = Main%theta(i-2,k) + Main%theta(i+3,k)
			rhoutheta_vir(i,k) = virGrid%rho_0(i,k)*virGrid%u(i,k)/60.*(37*fa(i,k) - 8*fb(i,k) + fc(i,k))
			fd(i,k) = Main%theta(i+1,k) - Main%theta(i,k)
			fe(i,k) = Main%theta(i+2,k) - Main%theta(i-1,k)
			ff(i,k) = Main%theta(i+3,k) - Main%theta(i-2,k)
			rhoutheta_vir(i,k) = rhoutheta_vir(i,k) - ABS(virGrid%u(i,k))/60.*(10*fd(i,k) - 5*fe(i,k) + ff(i,k))
		END DO
	END DO
	!OMP END PARALLEL DO
CASE DEFAULT
	STOP "Wrong advection scheme!!!"
END SELECT
!-------------------------------------------------
! pi-grid
!-------------------------------------------------
CALL set_area_pi
CALL set_area_expand(expand)

SELECT CASE (AdvectionScheme)
CASE (5)
	!OMP PARALLEL DO
	DO k = kmin, kmax
		DO i = imin, imax
			fa(i,k) = Main%theta(i,k+1) + Main%theta(i,k)
			fb(i,k) = Main%theta(i,k+2) + Main%theta(i,k-1)
			fc(i,k) = Main%theta(i,k+3) + Main%theta(i,k-2)
			rhowtheta_pi(i,k) = piGrid%rho_0(i,k)*piGrid%w(i,k)/60.*(37*fa(i,k) - 8*fb(i,k) + fc(i,k))
			fd(i,k) = Main%theta(i,k+1) - Main%theta(i,k)
			fe(i,k) = Main%theta(i,k+2) - Main%theta(i,k-1)
			ff(i,k) = Main%theta(i,k+3) - Main%theta(i,k-2)
			rhowtheta_pi(i,k) = rhowtheta_pi(i,k) - ABS(piGrid%w(i,k))/60.*(10*fd(i,k) - 5*fe(i,k) + ff(i,k))
		END DO
	END DO
	!OMP END PARALLEL DO
CASE DEFAULT
	STOP "Wrong advection scheme!!!"
END SELECT
!-------------------------------------------------
! w-grid - Theta on kts and kte+1 should also be updated.
!-------------------------------------------------
CALL ppx_w(rhoutheta_vir,PrhouthetaPx_w)
CALL ppzeta_w(rhowtheta_pi,PrhowthetaPz_w)

CALL set_area_w

!OMP PARALLEL DO
DO k = kmin, kmax
	DO i = imin, imax
		uPthetaPx_w(i,k) = 1./wGrid%rho_0(i,k)*(PrhouthetaPx_w(i,k) - Main%theta(i,k)*PrhouPx_w(i,k))
		wPthetaPz_w(i,k) = 1./wGrid%rho_0(i,k)*(PrhowthetaPz_w(i,k) - Main%theta(i,k)*PrhowPz_w(i,k))
	
		F_theta(i,k) = - uPthetaPx_w(i,k) - wPthetaPz_w(i,k)
		tend_theta(i,k) = F_theta(i,k)
	END DO
END DO
!OMP END PARALLEL DO
	
IF (RunCase == 1 .OR. RunCase == 2) THEN
	!OMP PARALLEL DO
	DO k = kmin, kmax
		DO i = imin, imax
			P2thetaPx2_w(i,k) = (Main%theta(i+1,k) + Main%theta(i-1,k) - 2*Main%theta(i,k))/dx/dx
			P2thetaPz2_w(i,k) = (Main%theta(i,k+1) + Main%theta(i,k-1) - 2*Main%theta(i,k))/dz/dz
			
			tend_theta(i,k) = F_theta(i,k) + Kh*(P2thetaPx2_w(i,k) + P2thetaPz2_w(i,k)) ! Add diffusion term.
		END DO
	END DO
	!OMP END PARALLEL DO
END IF
!-------------------------------------------------
IF (ANY(ISNAN(F_theta(its:ite,kts:kte)))) STOP "SOMETHING IS WRONG WITH F_theta!!!"
!=================================================
END SUBROUTINE tendency_theta
!=================================================

!=================================================
SUBROUTINE ppx_u(var_pi,output)
IMPLICIT NONE
REAL(kd), DIMENSION(ims:ime,kms:kme), INTENT(IN) :: var_pi
REAL(kd), DIMENSION(ims:ime,kms:kme), INTENT(OUT) :: output
INTEGER :: i, k
CALL set_area_u
!OMP PARALLEL DO
DO k = kmin, kmax
	DO i = imin, imax
		output(i,k) = (var_pi(i+1,k) - var_pi(i,k))/dx
	END DO
END DO
!OMP END PARALLEL DO
END SUBROUTINE ppx_u
!=================================================

!=================================================
SUBROUTINE ppzeta_u(var_vir,output)
IMPLICIT NONE
REAL(kd), DIMENSION(ims:ime,kms:kme), INTENT(IN) :: var_vir
REAL(kd), DIMENSION(ims:ime,kms:kme), INTENT(OUT) :: output
INTEGER :: i, k
CALL set_area_u
!OMP PARALLEL DO
DO k = kmin, kmax
	DO i = imin, imax
		output(i,k) = (var_vir(i,k+1) - var_vir(i,k))/dz
	END DO
END DO
!OMP END PARALLEL DO
END SUBROUTINE ppzeta_u
!=================================================

!=================================================
SUBROUTINE ppx_w(var_vir,output)
IMPLICIT NONE
REAL(kd), DIMENSION(ims:ime,kms:kme), INTENT(IN) :: var_vir
REAL(kd), DIMENSION(ims:ime,kms:kme), INTENT(OUT) :: output
INTEGER :: i, k
CALL set_area_w
!OMP PARALLEL DO
DO k = kmin, kmax
	DO i = imin, imax
		output(i,k) = (var_vir(i,k) - var_vir(i-1,k))/dx
	END DO
END DO
!OMP END PARALLEL DO
END SUBROUTINE ppx_w
!=================================================

!=================================================
SUBROUTINE ppzeta_w(var_pi,output)
IMPLICIT NONE
REAL(kd), DIMENSION(ims:ime,kms:kme), INTENT(IN) :: var_pi
REAL(kd), DIMENSION(ims:ime,kms:kme), INTENT(OUT) :: output
INTEGER :: i, k
CALL set_area_w
!OMP PARALLEL DO
DO k = kmin, kmax
	DO i = imin, imax
		output(i,k) = (var_pi(i,k) - var_pi(i,k-1))/dz
	END DO
END DO
!OMP END PARALLEL DO
END SUBROUTINE ppzeta_w
!=================================================

!=================================================
SUBROUTINE ppx_pi(var_u,output)
IMPLICIT NONE
REAL(kd), DIMENSION(ims:ime,kms:kme), INTENT(IN) :: var_u
REAL(kd), DIMENSION(ims:ime,kms:kme), INTENT(OUT) :: output
INTEGER :: i, k
CALL set_area_pi
!OMP PARALLEL DO
DO k = kmin, kmax
	DO i = imin, imax
		output(i,k) = (var_u(i,k) - var_u(i-1,k))/dx
	END DO
END DO
!OMP END PARALLEL DO
END SUBROUTINE ppx_pi
!=================================================

!=================================================
SUBROUTINE ppzeta_pi(var_w,output)
IMPLICIT NONE
REAL(kd), DIMENSION(ims:ime,kms:kme), INTENT(IN) :: var_w
REAL(kd), DIMENSION(ims:ime,kms:kme), INTENT(OUT) :: output
INTEGER :: i, k
CALL set_area_pi
!OMP PARALLEL DO
DO k = kmin, kmax
	DO i = imin, imax
		output(i,k) = (var_w(i,k+1) - var_w(i,k))/dz
	END DO
END DO
!OMP END PARALLEL DO
END SUBROUTINE ppzeta_pi
!=================================================

!=================================================
END MODULE sp_module_tendency
!=================================================
